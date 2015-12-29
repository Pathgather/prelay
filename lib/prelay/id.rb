# frozen-string-literal: true

module Prelay
  class ID
    class << self
      def parse(string, expected_type: nil)
        type, id = parts = Base64.decode64(string).split(':')
        raise InvalidGraphQLQuery, "Not a valid object id: \"#{string}\"" unless parts.length == 2

        if expected_type && expected_type != type
          raise InvalidGraphQLQuery, "Expected object id for a #{expected_type}, got one for a #{type}"
        end

        new(type: type, id: id)
      end

      def encode(type:, id:)
        Base64.strict_encode64 "#{type}:#{id}"
      end

      def get(string)
        parse(string).get
      end
    end

    attr_reader :type, :id

    def initialize(type:, id:)
      @id   = id
      @type = Type::BY_NAME.fetch(type) { raise InvalidGraphQLQuery, "Not a valid object type: #{type}" }
    end

    def get
      @type.model[@id]
    end
  end
end
