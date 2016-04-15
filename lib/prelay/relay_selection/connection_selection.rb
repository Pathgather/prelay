# frozen_string_literal: true

module Prelay
  class RelaySelection
    class ConnectionSelection < self

      def initialize(selection, type:)
        raise Error, "Expected a GraphQLSelection, got a #{selection.class}" unless selection.is_a?(GraphQLSelection)

        metadata = {}

        selections =
          if edges = selection.selections[:edges]
            # It's against the Relay spec to request edges on connections
            # without either a 'first' or 'last' argument, but since the gem
            # doesn't stop it from happening, throw an error when/if that
            # happens, just to be safe. If we want to support that at some point
            # (allowing the client to load all records in a connection) we
            # could, but that behavior should be thought through, and a limit
            # should probably still be applied to prevent abuse.
            unless selection.arguments[:first] || selection.arguments[:last]
              raise Error, "Tried to access the connection '#{selection.name}' without a 'first' or 'last' argument."
            end
            EdgeSelection.new(edges, type: type).selections
          else
            {}
          end

        if page_info = selection.selections[:pageInfo]
          metadata[:has_next_page]     = true if page_info.selections[:hasNextPage]
          metadata[:has_previous_page] = true if page_info.selections[:hasPreviousPage]

          selections[:id] ||= RelaySelection.new(name: :id, type: type)
        end

        if selection.selections[:count]
          metadata[:count_requested] = true
        end

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
          selections: selections,
          metadata: metadata,
        )
      end
    end
  end
end
