# frozen_string_literal: true

module Prelay
  class RelaySelection
    class ConnectionSelection < self
      def initialize(selection, type:)
        raise Error, "Expected a GraphQLSelection, got a #{selection.class}" unless selection.is_a?(GraphQLSelection)

        @edges =
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

            EdgeSelection.new(edges, type: type)
          end

        @page_info = selection.selections[:pageInfo]

        @count = selection.selections[:count]

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
        )
      end

      def pagination_info_requested?
        @page_info && (@page_info.selections[:hasNextPage] || @page_info.selections[:hasPreviousPage])
      end

      def count_requested?
        !!@count
      end

      def cursor_requested?
        @edges.cursor_requested? if @edges
      end

      def columns
        columns = @edges ? @edges.columns : EMPTY_ARRAY
        columns += [:id] if pagination_info_requested?
        columns.uniq
      end

      def associations
        @edges ? @edges.associations : {}
      end
    end
  end
end
