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
    attr_reader :ast

    # For most queries we'll be passing in the context object for the entire
    # query, and we'll just process it from the top level. In some places
    # (responding to mutations, specifically) there may be several top-level
    # fields in a query that don't have an easily identifiable relationship to
    # one another, so we support passing in a field object and supplying the
    # query context separately for us to look up fragments on.

    # The calling code should know if the field being passed in is a Relay
    # connection or edge call, so it must provide an :entry_point argument to
    # tell us how to start parsing.
    def initialize(input, context: nil, model:, entry_point:)
      case input
      when GraphQL::Query::Context
        raise "Can't pass an additional context to RelayProcessor when giving it a GraphQL::Query::Context" if context
        context = input
        root_field = context.ast_node
      when GraphQL::Language::Nodes::Field
        raise "Must pass an additional GraphQL::Query::Context to RelayProcessor when giving it a GraphQL::Language::Nodes::Field" unless GraphQL::Query::Context === context
        root_field = input
      else
        raise "Unsupported input: #{input.class}"
      end

      @fragments = context.query.fragments

      # We use a stack to track the currently relevant model as we walk the
      # tree.
      @model_stack = [model]

      @ast =
        case entry_point
        when :field      then ast_for_field(root_field, model: model)
        when :connection then ast_for_relay_connection(root_field)
        when :edge       then Selection.new(name: root_field.name.to_sym, model: model, arguments: {}, selections: ast_for_relay_edge(root_field))
        else raise "Unsupported entry_point: #{entry_point}"
        end
    end

    def to_resolver
      DatasetResolver.new(ast: @ast)
    end

    private

    def ast_for_field(field, model: nil)
      Selection.new name:       field.name.to_sym,
                    model:      model,
                    arguments:  arguments_from_field(field),
                    selections: selections_from_field(field)
    end

    def arguments_from_field(field)
      field.arguments.each_with_object({}){|a, hash| hash[a.name.to_sym] = a.value}
    end

    def selections_from_field(field, ast = {})
      field.selections.each_with_object(ast){|s, ast| append_ast_for_selection(s, ast)}
    end

    def append_ast_for_selection(thing, ast)
      case thing
      when GraphQL::Language::Nodes::Field
        name = thing.name.to_sym
        key  = (thing.alias || name).to_sym

        new_ast =
          if attribute = current_model.attributes[name]
            ast_for_field(thing)
          elsif association = current_model.associations[name]
            push_model(association.target_model) do
              if association.returns_array?
                ast_for_relay_connection(thing)
              else
                ast_for_field(thing, model: current_model)
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

        if old_ast = ast[name]
          # This field was already declared, so merge this ast with the
          # previous one. We don't yet support declaring the same field twice
          # with different arguments, so fail in that case.
          old_ast.merge!(new_ast, fail_on_argument_difference: true) if old_ast != new_ast
        else
          ast[key] = new_ast
        end
      when GraphQL::Language::Nodes::FragmentSpread
        fragment = @fragments.fetch(thing.name) { raise InvalidGraphQLQuery, "fragment not found with name #{thing.name}" }
        selections_from_field(fragment, ast)
      when GraphQL::Language::Nodes::InlineFragment
        if Model::BY_TYPE.fetch(thing.type) == current_model
          selections_from_field(thing, ast)
        else
          # Fragment is on a different type than this is, so ignore it.
        end
      else
        raise InvalidGraphQLQuery, "unsupported GraphQL component: #{thing.class}"
      end
    end

    def ast_for_relay_connection(field)
      s = {}
      field.selections.each{|e| s[e.name] = e}

      arguments = arguments_from_field(field)

      unless edge = s.delete('edges'.freeze)
        raise InvalidGraphQLQuery, "can't specify a relay connection without an 'edges' field"
      end

      selections = ast_for_relay_edge(edge)

      s.each do |name, field|
        case name
        when 'pageInfo'.freeze
          field.selections.each do |field|
            case field.name
            when 'hasNextPage'.freeze     then arguments[:has_next_page]     = true
            when 'hasPreviousPage'.freeze then arguments[:has_previous_page] = true
            else raise InvalidGraphQLQuery, "unsupported field for Relay pageInfo: #{field.name}"
            end
          end
        else
          raise InvalidGraphQLQuery, "unsupported field for Relay connection: '#{name}'"
        end
      end

      Selection.new name:       field.name.to_sym,
                    model:      current_model,
                    arguments:  arguments,
                    selections: selections
    end

    def ast_for_relay_edge(field)
      s = {}
      field.selections.each{|e| s[e.name] = e}

      unless field.arguments.empty?
        raise InvalidGraphQLQuery, "arguments for Relay edge fields are unsupported"
      end

      unless node = s.delete('node'.freeze)
        raise InvalidGraphQLQuery, "can't specify a Relay edge without a 'node' field"
      end

      selections = selections_from_field(node)

      s.each do |name, field|
        case name
        when 'cursor'.freeze
          # Cursors are currently just the object's relay_id, but we want to
          # roll pagination information into the cursor at some point. But for
          # now, if the client wants the cursor, have to be sure we fetch the
          # object's uuid.
          selections[:id] ||= Selection.new(name: :id)
        else
          raise InvalidGraphQLQuery, "unsupported field for Relay edge: '#{name}'"
        end
      end

      selections
    end

    def current_model
      @model_stack.last
    end

    def push_model(model)
      @model_stack.push model
      yield
    ensure
      @model_stack.pop
    end
  end
end
