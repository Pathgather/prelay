# frozen_string_literal: true

module Prelay
  class Mutation
    class Argument
      attr_reader :name

      def initialize(klass, name, type, optional: false)
        @klass    = klass
        @name     = name
        @type     = type
        @optional = optional
      end

      def graphql_type
        t =
          case @type
          when GraphQL::BaseType then @type
          when :id               then GraphQL::ID_TYPE
          when :boolean          then GraphQL::BOOLEAN_TYPE
          when :text             then GraphQL::STRING_TYPE
          else raise "Unsupported argument type! #{@type.inspect}"
          end

        @optional ? t : !t
      end
    end
  end
end
