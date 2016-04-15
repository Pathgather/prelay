# frozen_string_literal: true

module Prelay
  class RelaySelection
    attr_reader :name, :type, :aliaz, :arguments

    def initialize(name:, type:, aliaz: nil, arguments: EMPTY_HASH)
      raise "RelaySelection initialized with a bad type: #{type.class}" unless type < Type

      @name      = name
      @type      = type
      @aliaz     = aliaz
      @arguments = arguments
    end

    def columns
      raise NotImplementedError
    end

    def associations
      raise NotImplementedError
    end
  end
end
