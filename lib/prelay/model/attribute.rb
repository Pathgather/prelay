# frozen-string-literal: true

module Prelay
  class Model
    class Attribute
      attr_reader :name, :type, :dependent_columns

      def initialize(model, name, type:, dependent_columns: nil)
        @model = model
        @name  = name
        @type  = type
        @dependent_columns = (dependent_columns || [name]).freeze
      end

      def graphql_type
        case @type
        when :string  then GraphQL::STRING_TYPE
        when :integer then GraphQL::INT_TYPE
        when :boolean then GraphQL::BOOLEAN_TYPE
        when :float   then GraphQL::FLOAT_TYPE
        else raise "Unsupported type for GraphQL: #{@type}"
        end
      end
    end
  end
end
