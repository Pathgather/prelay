# frozen_string_literal: true

require 'spec_helper'

class EdgeMutationSpec < PrelaySpec
  let(:artist) { Artist.first }

  mock_schema do
    mutation :CreateAlbum do
      type AlbumType

      argument :artist_id, :id
      argument :name,      :string

      result_field :artist,     association: :artist
      result_field :album,      association: :self
      result_field :album_edge, association: :self, edge: true

      def mutate(args)
        args[:artist] = Prelay::ID.parse(args.delete(:artist_id), expected_type: ArtistType, schema: self.class.schema).get

        album = Album.create(args)

        {artist: album.artist_id, album: album.id}
      end
    end
  end

  it "should support invoking a mutation that returns a node and an edge for it in relation to another node" do
    @input = {
      artist_id: id_for(artist),
      name: "New Album Name"
    }

    execute_mutation :create_album, graphql: <<-GRAPHQL
      artist {
        id,
        first_name
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
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("id" = '#{artist.id}') ORDER BY "created_at" DESC),
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
      %(SELECT "albums"."id", "albums"."name", "albums"."created_at" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
    ]

    assert_mutation_result \
      'artist' => {
        'id' => id_for(artist),
        'first_name' => artist.first_name,
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

  20.times do
    it "should support fuzzed queries for item edges" do
      @input = {
        artist_id: id_for(artist),
        name: "New Album Name"
      }

      artist_fuzzer     = GraphQLFuzzer.new(source: ArtistType)
      album_fuzzer      = GraphQLFuzzer.new(source: AlbumType)
      album_edge_fuzzer = GraphQLFuzzer.new(source: ArtistType.associations.fetch(:albums), entry_point: :edge)

      arq, arf = artist_fuzzer.graphql_and_fragments
      alq, alf = album_fuzzer.graphql_and_fragments
      aeq, aef = album_edge_fuzzer.graphql_and_fragments

      g =
        <<-GRAPHQL
          artist     { #{arq} }
          album      { #{alq} }
          album_edge { #{aeq} }
        GRAPHQL

      execute_mutation :create_album, graphql: g, fragments: (arf + alf + aef).shuffle

      albums = Album.where(name: "New Album Name").all
      assert_equal 1, albums.length
      album = albums.first

      assert_mutation_result \
        'artist'     => artist_fuzzer.expected_json(object: artist),
        'album'      => album_fuzzer.expected_json(object: album),
        'album_edge' => album_edge_fuzzer.expected_json(object: album)
    end
  end
end
