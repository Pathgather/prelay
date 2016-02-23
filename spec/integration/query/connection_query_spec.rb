# frozen_string_literal: true

require 'spec_helper'

class ConnectionQuerySpec < PrelaySpec
  mock_schema do
    type :Artist do
      string :first_name
    end

    type :Album do
      string :name
      many_to_one :artist, nullable: false
    end

    query :Albums do
      include Prelay::Connection
      type :Album
      order Sequel.desc(:created_at)
    end
  end

  it "should support returning a connection of many objects" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          albums(first: 5) {
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
    ]

    assert_result \
      'data' => {
        'connections' => {
          'albums' => {
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

  it "should support fuzzed queries"

  it "should support all types of pagination"
end
