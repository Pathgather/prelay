# frozen-string-literal: true

module Prelay
  class Schema
    def initialize(models: [])
      @models = models
    end

    def to_graphql_schema(prefix:)
      node_identification = GraphQL::Relay::GlobalNodeIdentification.define do
        type_from_object -> (object) do
          Prelay::Model::BY_SEQUEL_MODEL.fetch(object.class){|k| raise "No Prelay model found for class #{k}"}.graphql_object
        end
      end

      def node_identification.to_global_id(type, id)
        ID.encode(type: type, id: id)
      end

      @models.each do |model|
        model.define_graphql_object(node_identification)
      end

      GraphQL::Schema.new(
        query: GraphQL::ObjectType.define {
          name "#{prefix}Query"

          field :node, field: GraphQL::Field.define {
            type(node_identification.interface)
            argument :id, !GraphQL::ID_TYPE
            resolve -> (obj, args, ctx) {
              id = ID.parse(args['id'])
              RelayProcessor.new(ctx, model: id.model, entry_point: :field).
                to_resolver.resolve_by_pk(id.id)
            }
          }
        }
      )
    end
  end
end
