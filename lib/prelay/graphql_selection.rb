# frozen_string_literal: true

# A class representing a selection in a GraphQL query. Pretty basic, except
# that they can be recursively merged together when names collide. They have
# no awareness of the actual application schema at all.

module Prelay
  class GraphQLSelection
    attr_reader :name, :aliaz, :arguments, :selections, :fragments

    def initialize(name:, aliaz: nil, arguments: EMPTY_HASH, selections: EMPTY_HASH, fragments: EMPTY_HASH)
      @name       = name
      @aliaz      = aliaz
      @arguments  = arguments
      @selections = selections
      @fragments  = fragments
    end

    # Equality is used when deciding whether to bother to merge two selections
    # (since two empty selections is the most common case). It cares about
    # everything but the alias, since that won't matter when merging.
    def ==(other)
      self.class      == other.class &&
      self.name       == other.name &&
      self.arguments  == other.arguments &&
      self.selections == other.selections &&
      self.fragments  == other.fragments
    end

    # Merges together two GraphQLSelections. Is recursive, so also merges
    # their subfields, and those fields' subfields, and...
    def merge(other)
      raise Error, "Can't merge a GraphQLSelection with an object of a different class" unless other.is_a?(GraphQLSelection)
      raise Error, "Can't merge selections on different fields" unless name == other.name
      raise Error, "Query invokes the same field twice with different arguments" unless arguments == other.arguments

      self.class.new(
        name:       name,
        aliaz:      aliaz,
        arguments:  arguments,
        fragments:  fragments.merge(other.fragments)   { |k, o, n| o + n },
        selections: selections.merge(other.selections) { |k, o, n| o.merge(n) },
      )
    end
  end
end
