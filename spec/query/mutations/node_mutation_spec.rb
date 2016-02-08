# frozen_string_literal: true

require 'spec_helper'

class NodeMutationSpec < PrelaySpec
  it "should support invoking a mutation that returns a node" do
    album = Album.first
    id = id_for(album)

    execute_query <<-GRAPHQL
      mutation Mutation {
        update_album(input: {id: "#{id}", name: "New Album Name", clientMutationId: "blah"}) {
          album {
            id,
            name,
            artist {
              id,
              name
            }
          }
        }
      }
    GRAPHQL

    assert_sqls [
      %(SELECT * FROM "albums" WHERE "id" = '#{album.id}'),
      %(SAVEPOINT autopoint_1),
      %(UPDATE "albums" SET "name" = 'New Album Name' WHERE ("id" = '#{album.id}')),
      %(RELEASE SAVEPOINT autopoint_1),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist_id}')) ORDER BY "artists"."id"),
    ]

    assert_equal "New Album Name", album.reload.name

    assert_result \
      'data' => {
        'update_album' => {
          'album' => {
            'id' => id,
            'name' => "New Album Name",
            'artist' => {
              'id' => id_for(album.artist),
              'name' => album.artist.name,
            }
          }
        }
      }
  end
end
