# frozen_string_literal: true

require 'spec_helper'

class ArbitraryDatasetModelQuerySpec < PrelaySpec
  let(:album) { BestAlbum.first }

  it "should support models on arbitrary datasets, and not just tables" do
    id = encode 'BestAlbum', album.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on BestAlbum {
            name,
            artist {
              id,
              name
            },
            first_five_tracks(first: 10) {
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
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => encode("BestAlbum", album.id),
          'name' => album.name,
          'artist' => {
            'id' => encode("Artist", album.artist.id),
            'name' => album.artist.name
          },
          'first_five_tracks' => {
            'edges' => album.tracks_dataset.where(number: 1..5).all.sort_by(&:id).map { |track|
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

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("high_quality" AND ("albums"."id" = '#{album.id}')) ORDER BY "albums"."id"),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist.id}')) ORDER BY "artists"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}'))) ORDER BY "tracks"."id" LIMIT 10),
    ]
  end
end
