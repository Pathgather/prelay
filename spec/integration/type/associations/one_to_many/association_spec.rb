# frozen_string_literal: true

require 'spec_helper'

class OneToManyAssociationSpec < PrelaySpec
  let(:album)  { Album.first! }
  let(:artist) { album.artist }

  it "should support fetching associated items through a one-to-many association" do
    id = id_for(album)

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
            'edges' => album.tracks.map { |track|
              {
                'cursor' => to_cursor(track.created_at),
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
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", "tracks"."created_at" AS "cursor" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "created_at" LIMIT 50)
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
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id", "tracks"."created_at" AS "cursor" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "created_at" LIMIT 50)
    ]
  end

  it "should support fetching cursors but no nodes" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks(first: 50) {
              edges {
                cursor
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
            'edges' => album.tracks.map { |track|
              {
                'cursor' => to_cursor(track.created_at)
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."album_id", "tracks"."created_at" AS "cursor" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "created_at" LIMIT 50)
    ]
  end

  it "should support fetching pagination info but no edges" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks(first: 50) {
              pageInfo {
                hasNextPage
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
            'pageInfo' => {
              'hasNextPage' => false
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "created_at" LIMIT 51)
    ]
  end
end
