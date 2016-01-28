# frozen_string_literal: true

module Prelay
  class Schema
    def initialize(types: [])
      @types = types
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

      @types.each do |type|
        type.define_graphql_object(node_identification)
      end

      GraphQL::Schema.new(
        query: GraphQL::ObjectType.define {
          name "#{prefix}Query"

          field :node, field: GraphQL::Field.define {
            type(node_identification.interface)
            argument :id, !GraphQL::ID_TYPE
            resolve -> (obj, args, ctx) {
              id = ID.parse(args['id'])
              RelayProcessor.new(ctx, type: id.type).
                to_resolver.resolve_by_pk(id.pk)
            }
          }
        }
      )
    end
  end
end
