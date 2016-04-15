# frozen_string_literal: true

module Prelay
  class GraphQLSelection
    attr_accessor :name, :selections, :aliaz
    attr_reader :arguments, :fragments

    def initialize(name:, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, fragments: EMPTY_HASH)
      @name       = name
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @fragments  = fragments
    end

    def ==(other)
      self.class      == other.class &&
      self.name       == other.name &&
      self.arguments  == other.arguments &&
      self.selections == other.selections &&
      self.fragments  == other.fragments
    end

    # Merges together two selections. Is recursive, so also merges
    # subselections, and their subselections, and...
    def merge(other)
      raise Error, "Can't merge selections on different fields" unless name == other.name
      raise Error, "Query invokes the same field twice with different arguments" unless arguments == other.arguments

      self.class.new(
        name: name,
        aliaz: aliaz,
        arguments: arguments,
        fragments: fragments.merge(other.fragments) { |k, o, n| o + n },
        selections: selections.merge(other.selections) { |k, o, n| o.merge(n) },
      )
    end
  end
end
