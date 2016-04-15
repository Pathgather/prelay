# frozen_string_literal: true

module Prelay
  class RelaySelection
    class EdgeSelection < self
      def initialize(selection, target_types:)
        selections =
          if node = selection.selections[:node]
            FieldSelection.new(node, target_types: target_types).selections
          else
            {}
          end

        if selection.selections[:cursor]
          target_types.each do |type|
            (selections[type] ||= {})[:cursor] ||= RelaySelection.new(name: :cursor, types: [type])
          end
        end

        super(
          name: selection.name,
          types: target_types,
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
