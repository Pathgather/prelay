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

        @cursor =
          if selection.selections[:cursor]
            RelaySelection.new(name: :cursor, type: type)
          end

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
        )
      end

      def columns
        columns = @node ? @node.columns : EMPTY_ARRAY
        columns += [:cursor] if @cursor
        columns
      end

      def associations
        @node ? @node.associations : {}
      end
    end
  end
end
