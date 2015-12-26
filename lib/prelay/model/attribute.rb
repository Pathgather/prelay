# frozen-string-literal: true

module Prelay
  class Model
    class Attribute
      attr_reader :name, :type

      def initialize(model, name, type:)
        @model = model
        @name  = name
        @type  = type
      end

      def graphql_type
        case @type
        when :string  then GraphQL::STRING_TYPE
        when :integer then GraphQL::INT_TYPE
        else raise "Unsupported type for GraphQL: #{@type}"
        end
      end
    end
  end
end
