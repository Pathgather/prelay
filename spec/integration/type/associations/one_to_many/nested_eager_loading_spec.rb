# frozen_string_literal: true

require 'spec_helper'

class OneToManyNestedEagerLoadingSpec < PrelaySpec
  let(:artist) { Artist.first! }
  let(:albums) { artist.albums.first(3) }

  it "should support fetching limited fetching of items through nested one-to-many associations" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
            albums(first: 3) {
              count
              edges {
                node {
                  id,
                  name
                  tracks(first: 5) {
                    count
                    edges {
                      node {
                        id,
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'first_name' => artist.first_name,
          'albums' => {
            'count' => artist.albums_dataset.count,
            'edges' => albums.map { |album|
              {
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'tracks' => {
                    'count' => album.tracks_dataset.count,
                    'edges' => album.tracks.first(5).map { |track|
                      {
                        'node' => {
                          'id' => id_for(track),
                          'name' => track.name,
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "artist_id", count(*) AS "count" FROM (SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}'))) AS "t1" GROUP BY "artist_id"),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at" LIMIT 3),
      %(SELECT "album_id", count(*) AS "count" FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')}))) AS "t1" GROUP BY "album_id"),
      %(SELECT * FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", row_number() OVER (PARTITION BY "tracks"."album_id" ORDER BY "created_at") AS "prelay_row_number" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')}))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end

  it "should support fetching counts but no nodes" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            albums { count }
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'albums' => {
            'count' => artist.albums_dataset.count
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "artist_id", count(*) AS "count" FROM (SELECT "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}'))) AS "t1" GROUP BY "artist_id"),

      # Extraneous query, could be optimized away:
      %(SELECT "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at"),
    ]

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            albums(first: 3) {
              count
              edges {
                node {
                  tracks {
                    count
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'albums' => {
            'count' => artist.albums_dataset.count,
            'edges' => albums.map { |album|
              {
                'node' => {
                  'tracks' => {
                    'count' => album.tracks_dataset.count
                  }
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "artist_id", count(*) AS "count" FROM (SELECT "albums"."id", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}'))) AS "t1" GROUP BY "artist_id"),
      %(SELECT "albums"."id", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at" LIMIT 3),
      %(SELECT "album_id", count(*) AS "count" FROM (SELECT "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')}))) AS "t1" GROUP BY "album_id"),

      # Extraneous query, could be optimized away:
      %(SELECT "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')})) ORDER BY "created_at")
    ]
  end
end
