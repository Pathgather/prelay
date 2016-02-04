# frozen_string_literal: true

require 'spec_helper'

class ManyToOneInterfaceAssociationSpec < PrelaySpec
  it "should support fetching an associated item through a many-to-one association to an interface" do
    track = Track.exclude(album_id: nil).first!

    id = encode 'Track', track.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Track {
            name,
            release {
              __typename,
              id,
              name
            }
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => track.name,
          'release' => {
            '__typename' => "Album",
            'id' => encode("Album", track.album.id),
            'name' => track.album.name
          }
        }
      }

    assert_sqls [
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."release_id" FROM "tracks" WHERE ("tracks"."id" = '#{track.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."id" AS "cursor" FROM "albums" WHERE ("albums"."id" IN ('#{track.release_id}')) ORDER BY "id"),
      %(SELECT "compilations"."id", "compilations"."name", "compilations"."id" AS "cursor" FROM "compilations" WHERE ("compilations"."id" IN ('#{track.release_id}')) ORDER BY "id"),
    ]
  end
end
