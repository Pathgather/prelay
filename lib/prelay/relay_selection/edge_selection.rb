# frozen_string_literal: true

module Prelay
  class RelaySelection
    class EdgeSelection < self
      def initialize(selection, type:)
        raise Error, "Expected a GraphQLSelection, got a #{selection.class}" unless selection.is_a?(GraphQLSelection)

        selections =
          if node = selection.selections[:node]
            FieldSelection.new(node, type: type).selections
          else
            {}
          end

        if selection.selections[:cursor]
          selections[:cursor] ||= RelaySelection.new(name: :cursor, type: type)
        end

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
          selections: selections,
          fragments: selection.fragments,
          metadata: {},
        )
      end
    end
  end
end
