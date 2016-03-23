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

      def description(arg = nil)
        super(arg) || "Returns a set of #{graphql_field_name}"
      end

      def type(type = nil)
        if type && t = schema.find_type(type)
          t.filters.each do |name, (type, _)|
            arguments[name] = Query::Argument.new(self, name, type)
          end
        end

        super
      end

      def resolve
        -> (obj, args, ctx) {
          ast = GraphQLProcessor.new(ctx, schema: type.schema).ast
          RelayProcessor.new(ast, type: type, types_to_skip: types_to_skip, entry_point: :connection).
            to_resolver.resolve{|ds| ds.order(order)}
        }
      end
    end
  end
end
