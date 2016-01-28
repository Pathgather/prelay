# frozen_string_literal: true

module Prelay
  class GraphQLProcessor
    attr_reader :ast

    def initialize(input, fragments: nil)
      case input
      when GraphQL::Query::Context
        root_field = input.ast_node
        raise "Unsupported ast_node for input: #{root_field.class}" unless GraphQL::Language::Nodes::Field === root_field
        fragments = input.query.fragments
      when GraphQL::Language::Nodes::Field
        root_field = input
      else
        raise "Unsupported input: #{input.class}"
      end

      @fragments = fragments
      @ast = field_to_selection(root_field)
    end

    private

    def field_to_selection(field)
      selections, fragments = parse_field_selections_and_fragments(field)

      selection =
        Selection.new name:       field.name.to_sym,
                      aliaz:      field.alias&.to_sym,
                      type:       nil,
                      arguments:  arguments_from_field(field),
                      selections: selections,
                      fragments:  fragments
    end

    def arguments_from_field(field)
      field.arguments.each_with_object({}){|a, hash| hash[a.name.to_sym] = a.value}
    end

    def parse_field_selections_and_fragments(field, selections: {}, fragments: {}, type: nil)
      field.selections.each do |thing|
        case thing
        when GraphQL::Language::Nodes::Field
          name = thing.name.to_sym
          key  = thing.alias&.to_sym || name

          new_attr = field_to_selection(thing)

          if old_attr = selections[name] # TODO: Should this be key?
            # This field was already declared, so merge this selection with the
            # previous one. We don't yet support declaring the same field twice
            # with different arguments, so fail in that case.
            old_attr.merge!(new_attr, fail_on_argument_difference: true) if old_attr != new_attr
          else
            selections[key] = new_attr
          end
        when GraphQL::Language::Nodes::InlineFragment
          type = Type::BY_NAME.fetch(thing.type)
          s, f = parse_field_selections_and_fragments(thing)
          fragments.merge!(f) { |k,o,n| o + n }
          (fragments[type] ||= []) << s
        when GraphQL::Language::Nodes::FragmentSpread
          fragment = @fragments.fetch(thing.name) { raise InvalidGraphQLQuery, "fragment not found with name #{thing.name}" }

          if type = Type::BY_NAME[fragment.type]
            s, f = parse_field_selections_and_fragments(fragment)
            fragments.merge!(f) { |k,o,n| o + n }
            (fragments[type] ||= []) << s
          else
            parse_field_selections_and_fragments(fragment, selections: selections, fragments: fragments)
          end
        else
          raise "Unsupported input: #{selection.class}"
        end
      end

      [selections, fragments]
    end
  end
end