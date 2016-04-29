# frozen_string_literal: true

# The class responsible for taking the GraphQL AST from the gem and
# recursively transforming it into our own nested set of GraphQLSelection
# objects. Makes sure the rest of our code doesn't have to worry about things
# like named fragments or changes in the GraphQL gem itself.

module Prelay
  class GraphQLProcessor
    attr_reader :ast

    class << self
      def process(input, schema: Prelay.primary_schema)
        unless input.is_a? ::GraphQL::Query::Context
          raise Error, "Unsupported input for #{self}.process(): #{input.class}"
        end

        new(input.ast_node, fragments: input.query.fragments, schema: schema).ast
      end
    end

    def initialize(field, fragments:, schema:)
      unless field.is_a? ::GraphQL::Language::Nodes::Field
        raise Error, "Unsupported input for #{self}#initialize(): #{field.class}"
      end

      @fragments = fragments
      @schema = schema
      @ast = field_to_selection(field)
    end

    private

    def field_to_selection(field)
      selections, fragments = parse_field_selections_and_fragments(field)

      GraphQLSelection.new(
        name:       field.name.to_sym,
        aliaz:      field.alias&.to_sym,
        arguments:  field.arguments.each_with_object({}){|a, hash| hash[a.name.to_sym] = a.value},
        selections: selections,
        fragments:  fragments,
      )
    end

    def parse_field_selections_and_fragments(field, selections: {}, fragments: {}, type: nil)
      field.selections.each do |thing|
        case thing
        when GraphQL::Language::Nodes::Field
          name = thing.name.to_sym
          key  = thing.alias&.to_sym || name

          new_attr = field_to_selection(thing)

          selections[key] =
            if (old_attr = selections[key]) && old_attr != new_attr
              # This field was already declared, so merge this selection with the
              # previous one. We don't yet support declaring the same field twice
              # with different arguments, so fail in that case.
              old_attr.merge(new_attr)
            else
              new_attr
            end

        when GraphQL::Language::Nodes::InlineFragment
          type = @schema.type_for_name!(thing.type)
          s, f = parse_field_selections_and_fragments(thing)
          fragments.merge!(f) { |k,o,n| o + n }
          (fragments[type] ||= []) << s
        when GraphQL::Language::Nodes::FragmentSpread
          fragment = @fragments.fetch(thing.name) { raise Error, "fragment not found with name #{thing.name}" }

          if type = @schema.type_for_name(fragment.type)
            s, f = parse_field_selections_and_fragments(fragment)
            fragments.merge!(f) { |k,o,n| o + n }
            (fragments[type] ||= []) << s
          else
            # Something like "ModelEdge", "ModelConnection", "PageInfo", or
            # "Node". Whatever the contents, just throw them in with the main
            # selections, though we could stand to be more rigorous here.
            parse_field_selections_and_fragments(fragment, selections: selections, fragments: fragments)
          end
        else
          raise Error, "Unsupported input: #{selection.class}"
        end
      end

      [selections, fragments]
    end
  end
end
