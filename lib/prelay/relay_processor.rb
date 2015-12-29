# frozen-string-literal: true

# This class should:

#   - Transform the GraphQL gem's AST to our own format, so that the rest of
#     the query-servicing logic is insulated from changes to the GraphQL gem.
#   - Inline GraphQL fragments, including ones that are type-dependent.
#   - Validate that all the attributes and associations being accessed exist
#     on the given models.
#   - Return sensible errors if any of the frontend peeps sends us a malformed
#     GraphQL/Relay query or tries to invoke GraphQL/Relay features that we
#     don't support yet.
#   - Fail loudly if a GraphQL query generally isn't what we expect. Since
#     malicious GraphQL requests are a possible attack vector for us, we want
#     to be careful to validate this input.

module Prelay
  class RelayProcessor
    attr_accessor :current_model, :current_context

    # For most queries we'll be passing in the context object for the entire
    # query, and we'll just process it from the top level. In some places
    # (responding to mutations, specifically) there may be several top-level
    # fields in a query that don't have an easily identifiable relationship to
    # one another, so we support passing in a field object and supplying the
    # query context separately for us to look up fragments on.

    def initialize(context, model:)
      @fragments = context.query.fragments
      @selection = scope_model(model) { field_to_selection(context.ast_node) }
    end

    def to_resolver
      DatasetResolver.new(selection: @selection)
    end

    private

    def field_to_selection(field)
      Selection.new name:       field.name.to_sym,
                    model:      current_model,
                    arguments:  arguments_from_field(field),
                    attributes: attributes_from_field(field)
    end

    def scope_model(model)
      previous_model = current_model
      self.current_model = model
      yield
    ensure
      self.current_model = previous_model
    end

    def arguments_from_field(field)
      field.arguments.each_with_object({}){|a, hash| hash[a.name.to_sym] = a.value}
    end

    def attributes_from_field(field, attributes = {})
      field.selections.each_with_object(attributes){|s, attrs| append_attribute_for_selection(s, attrs)}
    end

    def process_fragments(thing, &block)
      case thing
      when GraphQL::Language::Nodes::FragmentSpread
        fragment = @fragments.fetch(thing.name) do
          raise InvalidGraphQLQuery, "fragment not found with name #{thing.name}"
        end

        fragment.selections.each do |selection|
          process_fragments(selection, &block)
        end
      when GraphQL::Language::Nodes::InlineFragment
        if Model::BY_TYPE.fetch(thing.type) == current_model
          thing.selections.each do |selection|
            process_fragments(selection, &block)
          end
        else
          # Fragment is on a different type than this is, so ignore it.
        end
      when GraphQL::Language::Nodes::Field
        yield thing
      else
        raise "Unsupported GraphQL input: #{thing.class}"
      end
    end

    def append_attribute_for_selection(thing, attrs)
      process_fragments(thing) do |field|
        name = field.name.to_sym
        key  = field.alias&.to_sym || name

        new_attr =
          if attribute = current_model.attributes[name]
            field_to_selection(field)
          elsif association = current_model.associations[name]
            scope_model(association.target_model) do
              if association.returns_array?
                arguments  = {}
                attributes = {}

                field.selections.each do |s1|
                  process_fragments(s1) do |f1|
                    case f1.name
                    when 'edges'
                      f1.selections.each do |s2|
                        process_fragments(s2) do |f2|
                          case f2.name
                          when 'node'
                            attributes_from_field(f2, attributes)
                          else
                            raise InvalidGraphQLQuery, "unsupported field '#{f2.name}'"
                          end
                        end
                      end
                    else
                      raise InvalidGraphQLQuery, "unsupported field '#{f1.name}'"
                    end
                  end
                end

                Selection.new name:       name,
                              model:      current_model,
                              arguments:  arguments,
                              attributes: attributes
              else
                field_to_selection(field)
              end
            end
          else
            case name
            when :id
              # id' isn't one of our declared attributes because it's handled
              # via the node identification interface included into all the
              # GraphQL objects derived from our models, but it still needs to
              # be retrieved from the DB, so we include it in our selection.

              Selection.new(name: name)
            when :clientMutationId, :__typename
              # These are acceptable fields to request, but the GraphQL gem
              # handles them, so we can just ignore them.
              return
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
    end
  end
end
