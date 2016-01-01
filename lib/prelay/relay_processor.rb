# frozen-string-literal: true

# This class should:

#   - Transform the GraphQL gem's AST to our own format, so that the rest of
#     the query-servicing logic is insulated from changes to the GraphQL gem.
#   - Inline GraphQL fragments, including ones that are type-dependent.
#   - Validate that all the attributes and associations being accessed exist
#     on the given types.
#   - Return sensible errors if any of the frontend peeps sends us a malformed
#     GraphQL/Relay query or tries to invoke GraphQL/Relay features that we
#     don't support yet.
#   - Fail loudly if a GraphQL query generally isn't what we expect. Since
#     malicious GraphQL requests are a possible attack vector for us, we want
#     to be careful to validate this input.

module Prelay
  class RelayProcessor
    attr_accessor :current_type

    # For most queries we'll be passing in the context object for the entire
    # query, and we'll just process it from the top level. In some places
    # (responding to mutations, specifically) there may be several top-level
    # fields in a query that don't have an easily identifiable relationship to
    # one another, so we support passing in a field object and supplying the
    # query context separately for us to look up fragments on.

    def initialize(context, type:)
      @fragments = context.query.fragments
      @selection = scope_type(type) { field_to_selection(context.ast_node) }
    end

    def to_resolver
      DatasetResolver.new(selection: @selection)
    end

    private

    def field_to_selection(field)
      Selection.new name:       field.name.to_sym,
                    type:       current_type,
                    arguments:  arguments_from_field(field),
                    attributes: attributes_from_field(field)
    end

    def connection_to_selection(field)
      arguments  = arguments_from_field(field)
      attributes = {}

      # It's against the Relay spec for connections to be invoked without either
      # a 'first' or 'last' argument, but since the gem doesn't stop it from
      # happening, throw an error when/if that happens, just to be safe. If we
      # want to support that at some point (allowing the client to load all
      # records in a connection) we could, but that behavior should be thought
      # through, and a limit should probably still be applied to prevent abuse.
      unless arguments[:first] || arguments[:last]
        raise InvalidGraphQLQuery, "Tried to access a connection without a 'first' or 'last' argument."
      end

      process_field_selections(field) do |f1|
        case f1.name
        when 'edges'
          process_field_selections(f1) do |f2|
            case f2.name
            when 'node'
              attributes_from_field(f2, attributes)
            else
              raise InvalidGraphQLQuery, "unsupported field '#{f2.name}'"
            end
          end
        when 'pageInfo'
          # TODO: Error on unexpected pageInfo fields.
          s = f1.selections.map(&:name)
          arguments[:has_next_page]     = true if s.include?('hasNextPage')
          arguments[:has_previous_page] = true if s.include?('hasPreviousPage')
        else
          raise InvalidGraphQLQuery, "unsupported field '#{f1.name}'"
        end
      end

      Selection.new name:       field.name.to_sym,
                    type:       current_type,
                    arguments:  arguments,
                    attributes: attributes
    end

    def arguments_from_field(field)
      field.arguments.each_with_object({}){|a, hash| hash[a.name.to_sym] = a.value}
    end

    def attributes_from_field(field, attrs = {})
      process_field_selections(field) do |field|
        name = field.name.to_sym
        key  = field.alias&.to_sym || name

        new_attr =
          if attribute = current_type.attributes[name]
            field_to_selection(field)
          elsif association = current_type.associations[name]
            scope_type(association.target_type) do
              if association.returns_array?
                connection_to_selection(field)
              else
                field_to_selection(field)
              end
            end
          else
            case name
            when :id
              # id' isn't one of our declared attributes because it's handled
              # via the node identification interface included into all the
              # GraphQL objects derived from our types, but it still needs to
              # be retrieved from the DB, so we include it in our selection.

              Selection.new(name: name)
            when :clientMutationId, :__typename
              # These are acceptable fields to request, but the GraphQL gem
              # handles them, so we can just ignore them.
              next
            else
              # Whatever field was requested, it ain't good.
              raise InvalidGraphQLQuery, "unsupported field '#{name}'"
            end
          end

        if old_attr = attrs[name]
          # This field was already declared, so merge this selection with the
          # previous one. We don't yet support declaring the same field twice
          # with different arguments, so fail in that case.
          old_attr.merge!(new_attr, fail_on_argument_difference: true) if old_attr != new_attr
        else
          attrs[key] = new_attr
        end
      end

      attrs
    end

    # Takes care of flattening fragment invocations, and only yields actual
    # field nodes to the given block.
    def process_field_selections(field, &block)
      field.selections.each do |thing|
        case thing
        when GraphQL::Language::Nodes::FragmentSpread
          fragment = @fragments.fetch(thing.name) { raise InvalidGraphQLQuery, "fragment not found with name #{thing.name}" }
          process_field_selections(fragment, &block)
        when GraphQL::Language::Nodes::InlineFragment
          if Type::BY_NAME.fetch(thing.type) == current_type
            process_field_selections(thing, &block)
          else
            # Fragment is on a different type than this is, so ignore it.
          end
        when GraphQL::Language::Nodes::Field
          yield thing
        else
          raise "Unsupported GraphQL input: #{thing.class}"
        end
      end
    end

    # Super-simple scoping of the current type class as we walk the AST.
    def scope_type(type)
      previous_type = current_type
      self.current_type = type
      yield
    ensure
      self.current_type = previous_type
    end
  end
end
