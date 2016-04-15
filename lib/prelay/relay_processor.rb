# frozen_string_literal: true

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

    def to_resolver
      DatasetResolver.new(selections_by_type: @selections_by_type)
    end
  end
end
