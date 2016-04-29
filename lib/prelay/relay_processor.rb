# frozen_string_literal: true

# The RelayProcessor class is responsible for taking a structure of
# GraphQLSelections and applying the schema of application types to them,
# converting them into RelaySelection objects that are more specialized.

module Prelay
  class RelayProcessor
    attr_reader :input

    # The calling code should know if the field being passed in is a Relay
    # connection or edge call, so it must provide an :entry_point argument to
    # tell us how to start parsing.
    def initialize(input, target_types:, entry_point:)
      @input = input
      klass = case entry_point
              when :field      then RelaySelection::FieldSelection
              when :connection then RelaySelection::ConnectionSelection
              when :edge       then RelaySelection::EdgeSelection
              else raise Error, "Unsupported entry_point: #{entry_point}"
              end

      @selections_by_type = {}

      target_types.map(&:covered_types).flatten.uniq.each do |target_type|
        @selections_by_type[target_type] = klass.new(input, type: target_type)
      end
    end

    def to_resolver(order: nil, supplemental_columns: [], &block)
      DatasetResolver.new(selections_by_type: @selections_by_type, order: order, supplemental_columns: supplemental_columns, &block)
    end
  end
end
