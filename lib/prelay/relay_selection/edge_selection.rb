# frozen_string_literal: true

module Prelay
  class RelaySelection
    class EdgeSelection < self
      def initialize(selection, type:)
        raise Error, "Expected a GraphQLSelection, got a #{selection.class}" unless selection.is_a?(GraphQLSelection)

        @node =
          if node = selection.selections[:node]
            FieldSelection.new(node, type: type)
          end

        @cursor = !!selection.selections[:cursor]

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
        )
      end

      def columns
        @node ? @node.columns : EMPTY_ARRAY
      end

      def cursor_requested?
        @cursor
      end

      def associations
        @node ? @node.associations : EMPTY_HASH
      end
    end
  end
end
