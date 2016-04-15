# frozen_string_literal: true

module Prelay
  class RelaySelection
    attr_reader :name, :type, :aliaz, :arguments, :selections, :metadata

    def initialize(name:, type:, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, metadata: {})
      raise "RelaySelection initialized with a bad type: #{type.class}" unless type < Type

      @name       = name
      @type       = type
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @metadata   = metadata
    end
  end
end
