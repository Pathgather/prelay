# frozen_string_literal: true

require 'prelay/query/argument'

module Prelay
  class Query
    class << self
      [:type, :description, :resolve, :types_to_skip].each { |m| eval "def #{m}(arg = nil); arg ? @#{m} = arg : @#{m}; end" }

      def arguments
        @arguments ||= WriteOnceHash.new
      end

      def argument(*args)
        arguments[args.first] = Argument.new(self, *args)
      end

      def graphql_field_name
        to_s.chomp('Query').underscore
      end

      def build_graphql_object(config)
        config.name(graphql_field_name)
        config.description(type.description)
        config.type(graphql_type)
        config.resolve(resolve)

        arguments.each_value do |a|
          config.argument a.name, a.graphql_type
        end
      end

      def create_graphql_field(config)
        config.send(graphql_field_type, graphql_field_name, &method(:build_graphql_object))
      end

      def graphql_field_type
        :field
      end

      def graphql_type
        type.graphql_object
      end
    end
  end
end
