# frozen-string-literal: true

module Prelay
  class Selection
    attr_reader :name, :type, :aliaz, :arguments, :attributes, :metadata

    def initialize(name:, type: nil, aliaz: nil, arguments: {}, attributes: {}, metadata: {})
      @name       = name
      @type       = type
      @aliaz      = aliaz
      @arguments  = arguments
      @attributes = attributes
      @metadata   = metadata
    end

    # Merges together two selections. Is recursive, so also merges
    # subselections, and their subselections, and...
    def merge!(other_selection, fail_on_argument_difference:)
      # We could be smarter about this, but don't add the complexity until we need it.
      if fail_on_argument_difference && arguments != other_selection.arguments
        raise InvalidGraphQLQuery.new("This query invokes the same field twice with differing arguments")
      end

      @attributes = attributes.merge(other_selection.attributes) do |k, o, n|
        o.merge!(n, fail_on_argument_difference: fail_on_argument_difference)
      end

      self
    end
  end
end
