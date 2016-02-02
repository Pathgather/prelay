# frozen_string_literal: true

module Prelay
  module Connection
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def order(order = nil)
        if order
          @order = order
        else
          @order
        end
      end

      def graphql_field_type
        :connection
      end

      def graphql_type
        super.connection_type
      end

      def description
        super || "Returns a set of #{graphql_field_name}"
      end

      def resolve
        -> (obj, args, ctx) {
          ast = GraphQLProcessor.new(ctx).ast
          RelayProcessor.new(ast, type: type, types_to_skip: types_to_skip, entry_point: :connection).
            to_resolver.resolve(order: order || :created_at.asc)
        }
      end
    end
  end
end
