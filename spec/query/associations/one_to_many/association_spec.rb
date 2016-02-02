# frozen_string_literal: true

require 'spec_helper'

class OneToManyAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support fetching associated items through a one-to-many association" do
    id = encode 'Album', album.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks(first: 50) {
              edges {
                cursor,
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
          'id' => id,
          'name' => album.name,
          'tracks' => {
            'edges' => album.tracks.sort_by(&:number).map { |track|
              {
                'cursor' => to_cursor(track.number),
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
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", "tracks"."number" AS "cursor" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "number" LIMIT 50)
    ]
  end

  it "should not fail if a record has no associated items" do
    album.tracks_dataset.delete

    id = encode 'Album', album.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks(first: 50) {
              edges {
                cursor,
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
          'id' => id,
          'name' => album.name,
          'tracks' => {
            'edges' => []
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", "tracks"."number" AS "cursor" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "number" LIMIT 50)
    ]
  end
end
