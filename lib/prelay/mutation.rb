# frozen_string_literal: true

require 'prelay/mutation/argument'
require 'prelay/mutation/result_field'

module Prelay
  class Mutation
    extend Subclassable

    def initialize(arguments:)
      @args = arguments
    end

    def execute
      mutate(@args)
    end

    private

    # TODO: Remove or test. GraphQLError is app-specific, at the very least.
    def attempt_save(object)
      if !object.modified? || object.save(raise_on_failure: false)
        object
      else
        raise GraphQLError.new(validation_errors: object.errors)
      end
    end

    class << self
      [:description].each { |m| eval "def #{m}(arg = nil); arg ? @#{m} = arg : @#{m}; end" }

      def name(n = nil)
        if n
          @name = n
        else
          @name ||= super()
        end
      end

      def type(t = nil)
        if t
          @type = schema.find_type(t) || raise(DefinitionError, "couldn't find a type or interface named #{t}")
        else
          @type
        end
      end

      def arguments
        @arguments ||= {}
      end

      def result_fields
        @result_fields ||= {}
      end

      def argument(*args)
        arguments[args.first] = Argument.new(self, *args)
      end

      def result_field(*args)
        result_fields[args.first] = ResultField.new(self, *args)
      end

      def graphql_object_class
        GraphQL::Relay::Mutation
      end

      def graphql_field_name
        name.chomp('Mutation').gsub(/(.)([A-Z])/,'\1_\2').downcase
      end

      def create_graphql_field(config)
        config.field graphql_field_name, field: graphql_object.field
      end

      def graphql_object
        @graphql_object ||= graphql_object_class.define(&method(:build_graphql_object))
      end

      def build_graphql_object(config)
        config.name(name)
        config.description(description)

        arguments.each_value do |argument|
          config.input_field(argument.name, argument.graphql_type)
        end

        result_fields.each_value do |result_field|
          config.return_field result_field.name, result_field.graphql_type
        end

        symbolize_keys = proc do |thing|
          case thing
          when Array then thing.map(&symbolize_keys)
          when Hash  then thing.each_with_object({}) { |(key, value), hash| hash[key.to_sym] = symbolize_keys.call(value) }
          else            thing
          end
        end

        config.resolve -> (inputs, ctx) {
          args = symbolize_keys.call(inputs.to_h)
          args.delete(:clientMutationId)

          ids = new(arguments: args).execute

          result = {}
          selections = GraphQLProcessor.new(ctx, schema: schema).ast.selections

          result_fields.each_value do |result_field|
            if selection = selections[result_field.name]
              normalized = result_field.normalized_name
              result[result_field.name] =
                if (id = ids.fetch(normalized){raise "Mutation #{to_s} returned a results hash without a '#{normalized}' key!"})
                  if result_field.association
                    entry_point = result_field.edge? ? :edge : :field
                    resolver = RelayProcessor.new(selection, target_types: [result_field.target_type], entry_point: entry_point).to_resolver
                    record = resolver.resolve_singular{|ds| ds.where(id: id).order(Sequel.desc(:created_at))}

                    if result_field.edge?
                      GraphQL::Relay::Edge.new(record, SequelConnection.new(nil, nil))
                    else
                      record
                    end
                  else
                    id
                  end
                end
            end
          end

          result
        }
      end
    end
  end
end
