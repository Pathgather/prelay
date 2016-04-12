# frozen_string_literal: true

module Prelay
  class RelaySelection
    attr_reader :types, :selections, :graphql
    attr_reader :arguments, :metadata, :name, :aliaz

    def initialize(name:, types: nil, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, fragments: EMPTY_HASH, metadata: {})
      @name       = name
      @types      = types
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @fragments  = fragments
      @metadata   = metadata
    end

    # def initialize(graphql, type:)
    #   @graphql = graphql
    #   @type    = type

    #   s = graphql.selections

    #   (graphql.fragments[type] || EMPTY_ARRAY).each do |fragment_selections|
    #     s = s.merge(fragment_selections)
    #   end

    #   @selections = s
    # end
  end
end
