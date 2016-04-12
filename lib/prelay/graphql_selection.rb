# frozen_string_literal: true

module Prelay
  class GraphQLSelection
    attr_accessor :name, :types, :selections, :metadata, :aliaz
    attr_reader :arguments, :fragments

    def initialize(name:, types: nil, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, fragments: EMPTY_HASH, metadata: {})
      @name       = name
      @types      = types
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @fragments  = fragments
      @metadata   = metadata
    end

    def ==(other)
      self.class      == other.class &&
      self.name       == other.name &&
      self.types      == other.types &&
      self.arguments  == other.arguments &&
      self.selections == other.selections &&
      self.fragments  == other.fragments &&
      self.metadata   == other.metadata
    end

    # Merges together two selections. Is recursive, so also merges
    # subselections, and their subselections, and...
    def merge(other_selection, fail_on_argument_difference:)
      raise Error, "Query invokes the same field twice with different arguments" if fail_on_argument_difference && (arguments != other_selection.arguments)
      raise Error, "Can't merge selections on different fields" if name != other_selection.name
      raise Error, "Don't know yet how to merge typed selections" if types || other_selection.types
      raise Error, "Don't know yet how to merge selections with metadata" if metadata.any? || other_selection.metadata.any?

      self.class.new(
        name: name,
        types: nil,
        aliaz: aliaz,
        arguments: arguments.merge(other_selection.arguments),
        selections: selections.merge(other_selection.selections) { |k, o, n| o.merge(n, fail_on_argument_difference: fail_on_argument_difference) },
        fragments: fragments.merge(other_selection.fragments) { |k, o, n| o + n },
        metadata: {},
      )
    end
  end
end
