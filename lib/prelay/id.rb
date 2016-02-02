# frozen_string_literal: true

module Prelay
  class ID
    class << self
      def parse(string, expected_type: nil)
        type, pk = parts = Base64.decode64(string).split(':')
        raise InvalidGraphQLQuery, "Not a valid object id: \"#{string}\"" unless parts.length == 2

        if expected_type
          possible_types =
            if expected_type < Type
              [expected_type]
            elsif expected_type < Interface
              expected_type.types
            else
              raise "Bad expected_type: #{expected_type}"
            end

          expected_names = possible_types.map { |t| t.graphql_object.name }

          unless expected_names.include?(type)
            raise InvalidGraphQLQuery, "Expected object id for a #{expected_type.graphql_object.name}, got one for a #{type}"
          end
        end

        new(type: type, pk: pk)
      end

      def encode(type:, pk:)
        Base64.strict_encode64 "#{type}:#{pk}"
      end

      def for(record)
        type = Type::BY_MODEL.fetch(record.class) { raise "Could not find a Prelay::Type subclass corresponding to the #{record.class} model" }
        encode type: type.graphql_object, pk: record.pk
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
