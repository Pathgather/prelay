# frozen_string_literal: true

require 'spec_helper'

class CustomReturnTypeQuerySpec < PrelaySpec
  mock_schema do
    a = type :Artist do
      string :first_name
      string :last_name
    end

    custom_type = GraphQL::ObjectType.define do
      name "CustomReturnType"

      field :field1 do
        type GraphQL::STRING_TYPE
      end

      field :field2 do
        type GraphQL::INT_TYPE
      end

      field :artist do
        type a.graphql_object
      end
    end

    query :CustomReturnType do
      graphql_type(custom_type)

      resolve -> (obj, args, ctx) {
        ast = Prelay::GraphQLProcessor.new(ctx, schema: self.schema).ast.selections[:artist]
        artist = Prelay::RelayProcessor.new(ast, type: a, entry_point: :field).
          to_resolver.resolve_singular{|ds| ds.order(:id).limit(1)}

        OpenStruct.new(
          field1: "blah", field2: 2, artist: artist
        )
      }
    end
  end

  it "should support a custom return type for a query" do
    execute_query <<-GRAPHQL
      query Query {
        custom_return_type {
          field1,
          field2,
          artist {
            id,
            first_name,
            ...F1
          }
        }
      }

      fragment F1 on Artist {
        last_name
      }
    GRAPHQL

    artist = Artist.order(:id).first

    assert_result \
      'data' => {
        'custom_return_type' => {
          'field1' => 'blah',
          'field2' => 2,
          'artist' => {
            'id' => id_for(artist),
            'first_name' => artist.first_name,
            'last_name' => artist.last_name,
          }
        }
      }
  end
end
