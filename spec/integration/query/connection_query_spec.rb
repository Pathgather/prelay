# frozen_string_literal: true

require 'spec_helper'

class ConnectionQuerySpec < PrelaySpec
  mock_schema do
    query :Albums do
      include Prelay::Connection
      type AlbumType
      order Sequel.desc(:created_at)
    end
  end

  it "should support returning a connection of many objects" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          albums(first: 5) {
            count
            edges {
              cursor
              node {
                id,
                name,
                artist {
                  id,
                  first_name
                }
              }
            }
          }
        }
      }
    GRAPHQL

    albums = Album.order(Sequel.desc(:created_at)).limit(5).all

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" AS "cursor" FROM "albums" ORDER BY "created_at" DESC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
      %(SELECT count(*) AS "count" FROM "albums" LIMIT 1),
    ]

    assert_result \
      'data' => {
        'connections' => {
          'albums' => {
            'count' => Album.count,
            'edges' => albums.map { |album|
              {
                'cursor' => to_cursor(album.created_at),
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'artist' => {
                    'id' => id_for(album.artist),
                    'first_name' => album.artist.first_name,
                  }
                }
              }
            }
          }
        }
      }
  end

  20.times do
    it "should support fuzzed queries" do
      album_connection_fuzzer = GraphQLFuzzer.new(source: ArtistType.associations.fetch(:albums), entry_point: :connection)
      graphql, fragments = album_connection_fuzzer.graphql_and_fragments

      execute_query <<-GRAPHQL
        query Query {
          connections {
            albums(first: 5) { #{graphql} }
          }
        }
        #{fragments.join("\n")}
      GRAPHQL

      albums = Album.order(Sequel.desc(:created_at)).all

      assert_result \
        'data' => {
          'connections' => {
            'albums' => album_connection_fuzzer.expected_json(object: albums)
          }
        }
    end
  end

  it "should support different order clauses"

  it "should work with a type that has a 'cursor' field"

  describe "when on an interface" do
    it "should respect a list of specific types to return"
  end
end
