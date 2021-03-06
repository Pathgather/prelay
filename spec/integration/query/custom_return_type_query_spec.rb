# frozen_string_literal: true

require 'spec_helper'

class CustomReturnTypeQuerySpec < PrelaySpec
  mock_schema do
    custom_type = GraphQL::ObjectType.define do
      name "CustomReturnType"

      field :field1 do
        type GraphQL::STRING_TYPE
      end

      field :field2 do
        type GraphQL::INT_TYPE
      end

      field :artist do
        type ArtistType.graphql_object
      end
    end

    query :CustomReturnType do
      graphql_type(custom_type)

      resolve -> (obj, args, ctx) {
        ast = Prelay::GraphQLProcessor.process(ctx, schema: self.schema).selections[:artist]
        artist = Prelay::RelayProcessor.new(ast, target_types: [ArtistType], entry_point: :field).
          to_resolver(order: :id){|ds| ds.limit(1)}.resolve_singular

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

  it "should support aliases on the various return types"
end
