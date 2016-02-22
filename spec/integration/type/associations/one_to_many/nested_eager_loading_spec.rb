# frozen_string_literal: true

require 'spec_helper'

class OneToManyNestedEagerLoadingSpec < PrelaySpec
  let(:artist) { Artist.first! }
  let(:albums) { artist.albums.sort_by(&:release_date).reverse.first(3) }

  it "should support fetching limited fetching of items through nested one-to-many associations" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
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
          'first_name' => artist.first_name,
          'albums' => {
            'edges' => albums.map { |album|
              {
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'tracks' => {
                    'edges' => album.tracks.sort_by(&:number).first(5).map { |track|
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
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "release_date" DESC LIMIT 3),
      %(SELECT * FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", row_number() OVER (PARTITION BY "tracks"."album_id" ORDER BY "number") AS "prelay_row_number" FROM "tracks" WHERE ("tracks"."album_id" IN (#{albums.map{|a| "'#{a.id}'"}.join(', ')}))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end
end
