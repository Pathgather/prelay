# frozen_string_literal: true

module Prelay
  class ID
    class << self
      def parse(string, expected_type: nil, schema: Prelay.primary_schema)
        type, pk = parts = Base64.decode64(string).split(':')
        raise Error, "Not a valid object id: \"#{string}\"" unless parts.length == 2

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
            raise Error, "Expected object id for a #{expected_type.graphql_object.name}, got one for a #{type}"
          end
        end

        new(type: type, pk: pk, schema: schema)
      end

      def encode(type:, pk:)
        Base64.strict_encode64 "#{type}:#{pk}"
      end

      def for(record, schema: Prelay.primary_schema)
        type = schema.type_for_model!(record.class)
        encode type: type.graphql_object, pk: record.pk
      end

      def get(string, schema: Prelay.primary_schema)
        parse(string, schema: schema).get
      end

      def get!(string, schema: Prelay.primary_schema)
        parse(string, schema: schema).get!
      end
    end

    attr_reader :type, :pk

    def initialize(type:, pk:, schema: Prelay.primary_schema)
      @pk   = pk
      @type = schema.type_for_name!(type)
    end

    def get
      @type.model.with_pk(@pk)
    end

    def get!
      @type.model.with_pk!(@pk)
    end
  end
end
