# frozen_string_literal: true

require 'prelay/query/argument'

module Prelay
  class Query
    extend Subclassable

    class << self
      [:graphql_type, :description, :resolve, :target_types].each { |m| eval "def #{m}(arg = nil); arg ? @#{m} = arg : @#{m}; end" }

      def type(t = nil)
        if t
          @type = schema.find_type(t)
        else
          @type
        end
      end

      def name(n = nil)
        if n
          @name = n
        else
          @name || super()
        end
      end

      def arguments
        @arguments ||= {}
      end

      def argument(*args)
        arguments[args.first] = Argument.new(self, *args)
      end

      def graphql_field_name
        # CamelCase to under_score
        name.chomp('Query').gsub(/(.)([A-Z])/,'\1_\2').downcase
      end

      def build_graphql_object(config)
        config.name(graphql_field_name)
        config.description(description)
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

      def graphql_type(t = nil)
        if t
          @graphql_type = t
        else
          @graphql_type || type.graphql_object
        end
      end
    end
  end
end
