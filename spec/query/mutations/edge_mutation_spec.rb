# frozen_string_literal: true

require 'spec_helper'

class EdgeMutationSpec < PrelaySpec
  let(:artist) { Artist.first }

  it "should support invoking a mutation that returns a node and an edge for it in relation to another node" do
    @input = {
      artist_id: id_for(artist),
      name: "New Album Name"
    }

    execute_mutation :create_album, graphql: <<-GRAPHQL
      artist {
        id,
        name
      }
      album {
        id,
        name
      }
      album_edge {
        cursor
        node {
          id,
          name
        }
      }
    GRAPHQL

    album = Album.where(name: 'New Album Name').first!

    assert_sqls [
      %(SELECT * FROM "artists" WHERE "id" = '#{artist.id}'),
      %(SAVEPOINT autopoint_1),
      /INSERT INTO "albums"/,
      %(RELEASE SAVEPOINT autopoint_1),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("id" = '#{artist.id}') ORDER BY "created_at" DESC),
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
      %(SELECT "albums"."id", "albums"."name", "albums"."created_at" AS "cursor" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
    ]

    assert_mutation_result \
      'artist' => {
        'id' => id_for(artist),
        'name' => artist.name,
      },
      'album_edge' => {
        'cursor' => to_cursor(album.created_at),
        'node' => {
          'id' => id_for(album),
          'name' => album.name,
        }
      },
      'album' => {
        'id' => id_for(album),
        'name' => album.name,
      }
  end
end
