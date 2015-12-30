# frozen-string-literal: true

module Prelay
  class Type
    class Attribute
      attr_reader :name, :type, :dependent_columns

      def initialize(type, name, datatype:, dependent_columns: nil)
        @type = type
        @name = name
        @datatype = datatype
        @dependent_columns = (dependent_columns || [name]).freeze
      end

      def graphql_type
        case @datatype
        when :string  then GraphQL::STRING_TYPE
        when :integer then GraphQL::INT_TYPE
        when :boolean then GraphQL::BOOLEAN_TYPE
        when :float   then GraphQL::FLOAT_TYPE
        else raise "Unsupported type for GraphQL: #{@datatype}"
        end
      end
    end
  end
end