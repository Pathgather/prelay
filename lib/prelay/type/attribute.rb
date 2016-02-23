# frozen_string_literal: true

module Prelay
  class Type
    class Attribute
      attr_reader :parent, :name, :dependent_columns, :description, :graphql_type

      def initialize(parent, name, description = nil, datatype:, nullable: false, dependent_columns: nil)
        @parent            = parent
        @name              = name
        @description       = description
        @datatype          = datatype
        @dependent_columns = (dependent_columns || [name]).freeze

        base_type =
          case @datatype
          when :string    then GraphQL::STRING_TYPE
          when :integer   then GraphQL::INT_TYPE
          when :boolean   then GraphQL::BOOLEAN_TYPE
          when :float     then GraphQL::FLOAT_TYPE
          when :timestamp then Prelay::TimeType
          else raise "Unsupported type for GraphQL: #{@datatype}"
          end

        @graphql_type = nullable ? base_type : base_type.to_non_null_type
      end
    end
  end
end
