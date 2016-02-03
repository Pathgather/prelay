# frozen_string_literal: true

require 'prelay/mutation/argument'
require 'prelay/mutation/result_field'

module Prelay
  class Mutation
    def initialize(arguments:)
      @args = arguments
    end

    def execute
      mutate(@args)
    end

    private

    def attempt_save(object)
      if !object.modified? || object.save(raise_on_failure: false)
        object
      else
        raise GraphQLError.new(validation_errors: object.errors)
      end
    end

    class << self
      [:type, :description].each { |m| eval "def #{m}(arg = nil); arg ? @#{m} = arg : @#{m}; end" }

      def arguments
        @arguments ||= WriteOnceHash.new
      end

      def result_fields
        @result_fields ||= WriteOnceHash.new
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
        to_s.chomp('Mutation').underscore
      end

      def create_graphql_field(config)
        config.field graphql_field_name, field: graphql_object.field
      end

      def graphql_object
        @graphql_object ||= graphql_object_class.define(&method(:build_graphql_object))
      end

      def build_graphql_object(config)
        config.name(to_s)
        config.description(description)

        arguments.each_value do |argument|
          config.input_field(argument.name, argument.graphql_type)
        end

        result_fields.each_value do |result_field|
          config.return_field result_field.name, result_field.graphql_type
        end

        config.resolve -> (inputs, ctx) {
          args = inputs.to_h.symbolize_keys.except(:clientMutationId)
          ids = new(arguments: args).execute

          result = {}
          selections = GraphQLProcessor.new(ctx).ast.selections

          result_fields.each_value do |result_field|
            if selection = selections[result_field.name]
              normalized = result_field.normalized_name
              result[result_field.name] =
                if (id = ids.fetch(normalized){raise "Mutation #{to_s} returned a results hash without a '#{normalized}' key!"})
                  if result_field.association
                    entry_point = result_field.edge? ? :edge : :field
                    resolver = RelayProcessor.new(selection, type: result_field.target_type, entry_point: entry_point).to_resolver
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
