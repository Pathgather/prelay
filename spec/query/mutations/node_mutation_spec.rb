# frozen_string_literal: true

require 'spec_helper'

class NodeMutationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support invoking a mutation that returns a node" do
    @input = {
      id: id_for(album),
      name: "New Album Name"
    }

    execute_mutation :update_album, graphql: <<-GRAPHQL
      album {
        id,
        name,
        artist {
          id,
          name
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

    assert_mutation_result \
      'album' => {
        'id' => id_for(album),
        'name' => "New Album Name",
        'artist' => {
          'id' => id_for(album.artist),
          'name' => album.artist.name,
        }
      }
  end
end
