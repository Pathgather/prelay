# frozen_string_literal: true

module Prelay
  class Type
    class Attribute
      attr_reader :name, :type, :dependent_columns, :description, :graphql_type

      def initialize(type, name, description, datatype:, nullable: false, dependent_columns: nil)
        @type              = type
        @name              = name
        @description       = description
        @datatype          = datatype
        @dependent_columns = (dependent_columns || [name]).freeze

        base_type =
          case @datatype
          when :string  then GraphQL::STRING_TYPE
          when :integer then GraphQL::INT_TYPE
          when :boolean then GraphQL::BOOLEAN_TYPE
          when :float   then GraphQL::FLOAT_TYPE
          else raise "Unsupported type for GraphQL: #{@datatype}"
          end

        @graphql_type = nullable ? base_type : base_type.to_non_null_type
      end
    end
  end
end
