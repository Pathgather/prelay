# frozen_string_literal: true

require 'spec_helper'

class OneToManyNestedEagerLoadingSpec < PrelaySpec
  let(:artist) { Artist.first! }
  let(:albums) { artist.albums.sort_by(&:id).first(3) }

  it "should support fetching limited fetching of items through nested one-to-many associations" do
    id = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            name,
            albums(first: 3) {
              edges {
                node {
                  id,
                  name
                  tracks(first: 5) {
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
          'name' => artist.name,
          'albums' => {
            'edges' => albums.map { |album|
              {
                'node' => {
                  'id' => encode('Album', album.id),
                  'name' => album.name,
                  'tracks' => {
                    'edges' => album.tracks.sort_by(&:id).first(5).map { |track|
                      {
                        'node' => {
                          'id' => encode('Track', track.id),
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
      %(SELECT "artists"."id", "artists"."name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id"),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "albums"."id" LIMIT 3),
      %(SELECT * FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", row_number() OVER (PARTITION BY "tracks"."album_id" ORDER BY "tracks"."id") AS "prelay_row_number" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')}))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end
end
