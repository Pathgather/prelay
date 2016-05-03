# frozen_string_literal: true

require 'spec_helper'

class OneToOneFilteredAssociationSpec < PrelaySpec
  let(:album) { Album.first! }
  let(:first_track) { Track.first(number: 1, album: album) }

  it "should support fetching an associated item through a filtered one-to-one association" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            first_track {
              id,
              name
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
          'first_track' => {
            'id' => id_for(first_track),
            'name' => first_track.name,
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."release_id" FROM "tracks" WHERE (("number" = 1) AND ("tracks"."release_id" IN ('#{album.id}'))) ORDER BY "id")
    ]
  end

  it "should support attempting to fetch an associated item through a one-to-one association when it does not exist" do
    id = id_for(album)

    album.tracks_dataset.delete

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            first_track {
              id,
              name
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
          'first_track' => nil
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."release_id" FROM "tracks" WHERE (("number" = 1) AND ("tracks"."release_id" IN ('#{album.id}'))) ORDER BY "id")
    ]
  end
end
