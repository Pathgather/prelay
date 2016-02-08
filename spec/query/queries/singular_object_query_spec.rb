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
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" ORDER BY random() LIMIT 1),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist.id}')) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'random_album' => {
          'id' => id_for(album),
          'name' => album.name,
          'artist' => {
            'id' => id_for(album.artist),
            'name' => album.artist.name
          }
        }
      }
  end
end
