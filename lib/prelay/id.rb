# frozen-string-literal: true

module Prelay
  class ID
    class << self
      def parse(string, expected_type: nil)
        type, pk = parts = Base64.decode64(string).split(':')
        raise InvalidGraphQLQuery, "Not a valid object id: \"#{string}\"" unless parts.length == 2

        if expected_type && expected_type != type
          raise InvalidGraphQLQuery, "Expected object id for a #{expected_type}, got one for a #{type}"
        end

        new(type: type, pk: pk)
      end

      def encode(type:, pk:)
        Base64.strict_encode64 "#{type}:#{pk}"
      end

      def get(string)
        parse(string).get
      end
    end

    attr_reader :type, :pk

    def initialize(type:, pk:)
      @pk   = pk
      @type = Type::BY_NAME.fetch(type) { raise InvalidGraphQLQuery, "Not a valid object type: #{type}" }
    end

    def get
      @type.model[@pk]
    end
  end
end
