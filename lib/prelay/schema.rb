# frozen_string_literal: true

module Prelay
  class Schema
    attr_reader :types, :queries, :mutations, :interfaces

    def initialize(temporary: false)
      @types      = []
      @interfaces = []
      @queries    = []
      @mutations  = []

      SCHEMAS << self unless temporary
    end

    def to_graphql_schema(prefix:)
      node_identification = GraphQL::Relay::GlobalNodeIdentification.define do
        type_from_object -> (object) do
          Prelay::Type::BY_MODEL.fetch(object.record.class){|k| raise "No Prelay type found for class #{k}"}.graphql_object
        end
      end

      def node_identification.to_global_id(type, pk)
        ID.encode(type: type, pk: pk)
      end

      @types.each { |type| type.node_identification = node_identification }

      (@types + @interfaces).each &:graphql_object

      queries   = @queries
      mutations = @mutations

      GraphQL::Schema.new(
        query: GraphQL::ObjectType.define {
          name "#{prefix}Query"

          field :node, field: GraphQL::Field.define {
            type(node_identification.interface)
            argument :id, !GraphQL::ID_TYPE
            resolve -> (obj, args, ctx) {
              id = ID.parse(args['id'])
              ast = GraphQLProcessor.new(ctx).ast
              RelayProcessor.new(ast, type: id.type, entry_point: :field).
                to_resolver.resolve_singular{|ds| ds.where(Sequel.qualify(id.type.model.table_name, :id) => id.pk)}
            }
          }

          field :nodes, field: GraphQL::Field.define {
            type(node_identification.interface.to_list_type)
            argument :ids, !GraphQL::ID_TYPE.to_list_type
            resolve -> (obj, args, ctx) {
              args['ids'].map do |id|
                id = ID.parse(id)
                ast = GraphQLProcessor.new(ctx).ast
                RelayProcessor.new(ast, type: id.type, entry_point: :field).
                  to_resolver.resolve_singular{|ds| ds.where(Sequel.qualify(id.type.model.table_name, :id) => id.pk)}
              end
            }
          }

          connection_queries, other_queries = queries.sort_by(&:graphql_field_name).partition { |k| k < Prelay::Connection }

          # Relay wants connection queries to be located under a wrapper field, so
          # just call it 'connections'.
          field :connections do
            type GraphQL::ObjectType.define {
              name "ConnectionsQuery"
              description "Wrapper for connection queries"
              connection_queries.each { |q| q.create_graphql_field(self) }
            }

            # Since this field is just a wrapper, we won't actually use the result of
            # this resolve function, but the GraphQL gem expects it to be truthy, so...
            resolve -> (obj, args, ctx) { true }
          end

          other_queries.each { |q| q.create_graphql_field(self) }
        },

        mutation: GraphQL::ObjectType.define {
          name "#{prefix}Mutation"
          description "Mutations the client can run"
          mutations.sort_by(&:graphql_field_name).each { |m| m.create_graphql_field(self) }
        },

        # We don't support subscriptions yet, but have an empty object here so
        # that the full introspection query works.
        subscription: GraphQL::ObjectType.define {
          name "#{prefix}Subscription"
          description "Subscriptions the client can make"
        }
      )
    end
  end
end
