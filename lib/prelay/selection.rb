# frozen-string-literal: true

module Prelay
  class Selection
    attr_reader :name, :model, :arguments, :selections

    def initialize(name:, model: nil, arguments: {}, selections: {})
      @name       = name
      @model      = model
      @arguments  = arguments
      @selections = selections
    end

    def ==(other)
      self.class      == other.class &&
      self.name       == other.name &&
      self.model      == other.model &&
      self.arguments  == other.arguments &&
      self.selections == other.selections
    end

    # Merges together two selections. Is recursive, so also merges
    # subselections, and their subselections, and...
    def merge!(other_selection, fail_on_argument_difference:)
      # We could be smarter about this (it's probably fine if the arguments
      # are identical), but don't add the complexity until we need it.
      if fail_on_argument_difference && (arguments.any? || other_selection.arguments.any?)
        raise InvalidGraphQLQuery.new("This query invokes the same field twice with arguments")
      end

      return other_selection if frozen?

      @selections = selections.merge(other_selection.selections) do |k, o, n|
        o.merge!(n, fail_on_argument_difference: fail_on_argument_difference)
      end

      self
    end
  end
end
