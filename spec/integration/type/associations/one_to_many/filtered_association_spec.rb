# frozen_string_literal: true

require 'spec_helper'

class OneToManyFilteredAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support fetching associated items through a filtered one-to-many association" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            first_five_tracks(first: 50) {
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
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => album.name,
          'first_five_tracks' => {
            'count' => 5,
            'edges' => album.tracks_dataset.where(number: 1..5).map { |track|
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

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "album_id", count(*) AS "count" FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}')))) AS "t1" GROUP BY "album_id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}'))) ORDER BY "created_at" LIMIT 50),
    ]
  end

  it "should not fail if a record has no associated items" do
    album.tracks_dataset.delete

    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            first_five_tracks(first: 50) {
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
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => album.name,
          'first_five_tracks' => {
            'count' => 0,
            'edges' => []
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "album_id", count(*) AS "count" FROM (SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}')))) AS "t1" GROUP BY "album_id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}'))) ORDER BY "created_at" LIMIT 50),
    ]
  end
end
