# frozen_string_literal: true

require 'spec_helper'

class SingularObjectQuerySpec < PrelaySpec
  mock_schema do
    query :RandomAlbum do
      type :Album
      resolve -> (obj, args, ctx) {
        ast = Prelay::GraphQLProcessor.process(ctx)
        Prelay::RelayProcessor.new(ast, target_types: [AlbumType], entry_point: :field).
          to_resolver(order: Sequel.function(:random)){|ds| ds.limit(1)}.resolve_singular
      }
    end
  end

  it "should support returning a singular object" do
    execute_query <<-GRAPHQL
      query Query {
        random_album {
          id,
          name,
          artist {
            id,
            first_name
          }
        }
      }
    GRAPHQL

    pk = Base64.decode64(@result['data']['random_album']['id']).split(':').last
    album = Album[pk]

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" ORDER BY random() LIMIT 1),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist.id}')) ORDER BY "id"),
    ]

    assert_result \
      'data' => {
        'random_album' => {
          'id' => id_for(album),
          'name' => album.name,
          'artist' => {
            'id' => id_for(album.artist),
            'first_name' => album.artist.first_name
          }
        }
      }
  end
end
