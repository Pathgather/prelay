# frozen_string_literal: true

module Prelay
  class RelaySelection
    attr_reader :type, :selections, :graphql
    attr_reader :arguments, :metadata, :name, :aliaz, :fragments

    def initialize(name:, type:, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, fragments: EMPTY_HASH, metadata: {})
      raise "RelaySelection initialized with a bad type: #{type.class}" unless type < Type

      @name       = name
      @type       = type
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @fragments  = fragments
      @metadata   = metadata
    end
  end
end
