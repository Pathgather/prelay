# frozen_string_literal: true

module Prelay
  class Schema
    attr_reader :objects

    OBJECT_CLASSES = {
      Type      => :types,
      Interface => :interfaces,
      Query     => :queries,
      Mutation  => :mutations,
    }.freeze

    def initialize(temporary: false)
      @objects = {}

      OBJECT_CLASSES.each_key { |klass| @objects[klass] = [] }

      SCHEMAS << self unless temporary
    end

    OBJECT_CLASSES.each do |klass, plural|
      define_method(plural){@objects[klass]}
    end

    def types_and_interfaces
      types + interfaces
    end

    def find_type(t)
      case t
      when Class
        if t < Type
          t if types.include?(t)
        elsif t < Interface
          t if interfaces.include?(t)
        end
      when Symbol, String
        type_for_name(t.to_s)
      end
    end

    # TODO: Cache.
    def type_for_name(name)
      types_and_interfaces.find{|t| t.name == name}
    end

    # TODO: Cache.
    def type_for_model(model)
      types.find{|t| t.associated_models.include?(model)}
    end

    def type_for_name!(name)
      type_for_name(name) || raise(Error, "Type not found by name: #{name}")
    end

    def type_for_model!(model)
      type_for_model(model) || raise(Error, "Type not found for model: #{model}")
    end

    def node_identification
      @node_identification ||= begin
        schema = self

        node_identification =
          GraphQL::Relay::GlobalNodeIdentification.define do
            type_from_object -> (object) { schema.type_for_model!(object.record.class).graphql_object }
          end

        def node_identification.to_global_id(type, pk)
          ID.encode(type: type, pk: pk)
        end

        node_identification
      end
    end

    def graphql_schema(prefix: "Client")
      @graphql_schema ||= begin
        # Make sure that type and interface objects are defined before we
        # build the actual GraphQL schema.
        (@objects[Type] + @objects[Interface]).each &:graphql_object

        schema = self
        queries = @objects[Query]
        mutations = @objects[Mutation]

        GraphQL::Schema.new \
          query: GraphQL::ObjectType.define {
            name "#{prefix}Query"

            field :node, field: GraphQL::Field.define {
              type(schema.node_identification.interface)
              argument :id, !GraphQL::ID_TYPE
              resolve -> (obj, args, ctx) {
                id = ID.parse(args['id'], schema: schema)
                ast = GraphQLProcessor.new(ctx, schema: schema).ast
                RelayProcessor.new(ast, target_types: [id.type], entry_point: :field).
                  to_resolver.resolve_singular{|ds| ds.where(id.type.model.qualified_primary_key_hash(id.pk))}
              }
            }

            field :nodes, field: GraphQL::Field.define {
              type(schema.node_identification.interface.to_list_type)
              argument :ids, !GraphQL::ID_TYPE.to_list_type
              resolve -> (obj, args, ctx) {
                args['ids'].map do |id|
                  id = ID.parse(id, schema: schema)
                  ast = GraphQLProcessor.new(ctx, schema: schema).ast
                  RelayProcessor.new(ast, target_types: [id.type], entry_point: :field).
                    to_resolver.resolve_singular{|ds| ds.where(id.type.model.qualified_primary_key_hash(id.pk))}
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
      end
    end
  end
end
