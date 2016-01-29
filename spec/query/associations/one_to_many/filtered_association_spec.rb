# frozen_string_literal: true

require 'spec_helper'

class FilteredOneToManyAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support fetching associated items through a filtered one-to-many association" do
    id = encode 'Album', album.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            first_five_tracks(first: 50) {
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
            'edges' => album.tracks_dataset.where(number: 1..5).all.sort_by(&:number).map { |track|
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
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}'))) ORDER BY "number" LIMIT 50)
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
            first_five_tracks(first: 50) {
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
            'edges' => []
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" >= 1) AND ("number" <= 5) AND ("tracks"."album_id" IN ('#{album.id}'))) ORDER BY "number" LIMIT 50)
    ]
  end
end
