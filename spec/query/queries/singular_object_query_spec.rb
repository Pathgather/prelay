# frozen_string_literal: true

require 'spec_helper'

class SingularObjectQuerySpec < PrelaySpec
  it "should support returning a singular object" do
    execute_query <<-GRAPHQL
      query Query {
        random_album {
          id,
          name,
          artist {
            id,
            name
          }
        }
      }
    GRAPHQL

    pk = Base64.decode64(@result['data']['random_album']['id']).split(':').last
    album = Album[pk]

    assert_sqls [
      %(SELECT "id" FROM "albums" ORDER BY random() LIMIT 1),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist.id}')) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'random_album' => {
          'id' => encode("Album", album.id),
          'name' => album.name,
          'artist' => {
            'id' => encode("Artist", album.artist.id),
            'name' => album.artist.name
          }
        }
      }
  end
end
