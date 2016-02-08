# frozen_string_literal: true

require 'spec_helper'

class ConnectionQuerySpec < PrelaySpec
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
                  name
                }
              }
            }
          }
        }
      }
    GRAPHQL

    albums = Album.order(:name).limit(5).all

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."name" AS "cursor" FROM "albums" ORDER BY "name" ASC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'connections' => {
          'albums' => {
            'edges' => albums.map { |album|
              {
                'cursor' => to_cursor(album.name),
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'artist' => {
                    'id' => id_for(album.artist),
                    'name' => album.artist.name,
                  }
                }
              }
            }
          }
        }
      }
  end

  it "should support filters on the given type" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          albums(first: 5, are_high_quality: true) {
            edges {
              cursor
              node {
                id,
                name,
                artist {
                  id,
                  name
                }
              }
            }
          }
        }
      }
    GRAPHQL

    albums = Album.order(:name).where(:high_quality).limit(5).all

    assert_result \
      'data' => {
        'connections' => {
          'albums' => {
            'edges' => albums.map { |album|
              {
                'cursor' => to_cursor(album.name),
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'artist' => {
                    'id' => id_for(album.artist),
                    'name' => album.artist.name,
                  }
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."name" AS "cursor" FROM "albums" WHERE "high_quality" ORDER BY "name" ASC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
    ]
  end
end
