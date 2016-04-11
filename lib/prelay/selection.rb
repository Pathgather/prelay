# frozen_string_literal: true

module Prelay
  class Selection
    attr_accessor :name, :types, :selections, :metadata, :aliaz
    attr_reader :arguments, :fragments
    attr_accessor :count_requested

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
    def merge!(other_selection, fail_on_argument_difference:)
      if fail_on_argument_difference && (arguments != other_selection.arguments)
        raise Error, "Query invokes the same field twice with different arguments"
      end

      return other_selection if frozen?

      raise "Don't know yet how to merge typed and non-typed selections" unless types == other_selection.types

      @fragments = fragments.merge(other_selection.fragments) { |k, o, n| o + n }

      if types
        @selections = selections.merge(other_selection.selections) do |t, o, n|
          o.merge!(n) do |k, o, n|
            o.merge!(n, fail_on_argument_difference: fail_on_argument_difference)
          end
        end
      else
        @selections = selections.merge(other_selection.selections) do |k, o, n|
          o.merge!(n, fail_on_argument_difference: fail_on_argument_difference)
        end
      end

      self
    end
  end
end
