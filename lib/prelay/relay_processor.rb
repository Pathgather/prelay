# frozen_string_literal: true

module Prelay
  class RelayProcessor
    attr_reader :ast, :target_types

    # The calling code should know if the field being passed in is a Relay
    # connection or edge call, so it must provide an :entry_point argument to
    # tell us how to start parsing.
    def initialize(input, target_types:, entry_point:)
      target_types = target_types.map { |type| types_for_type(type) }.flatten.uniq

      klass = case entry_point
              when :field      then RelaySelection::FieldSelection
              when :connection then RelaySelection::ConnectionSelection
              when :edge       then RelaySelection::EdgeSelection
              else raise Error, "Unsupported entry_point: #{entry_point}"
              end

      @ast = klass.new(input, target_types: target_types)
    end

    def to_resolver
      DatasetResolver.new(ast: @ast)
    end

    private

    def types_for_type(type)
      if type < Type
        [type]
      elsif type < Interface
        type.types
      else
        raise Error, "Unexpected type: #{type}"
      end
    end
  end
end
