# frozen_string_literal: true

module Prelay
  class Query
    class Argument
      attr_reader :name

      def initialize(klass, name, type, optional: true)
        @klass    = klass
        @name     = name
        @type     = type
        @optional = optional
      end

      def nullable_graphql_type
        case @type
        when :string  then GraphQL::STRING_TYPE
        when :boolean then GraphQL::BOOLEAN_TYPE
        when :integer then GraphQL::INT_TYPE
        else raise "Unsupported type: #{@type}"
        end
      end

      def graphql_type
        t = nullable_graphql_type
        @optional ? t : !t
      end
    end
  end
end
