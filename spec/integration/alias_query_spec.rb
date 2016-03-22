# frozen_string_literal: true

require 'spec_helper'

class AliasQuerySpec < PrelaySpec
  let(:albums) { Album.limit(2).all }
  let(:album1) { albums[0] }
  let(:album2) { albums[1] }

  it "should support aliases for multiple invocations of the same query" do
    id1 = id_for album1
    id2 = id_for album2

    execute_query <<-GRAPHQL
      query Query {
        first: node(id: "#{id1}") {
          id,
          ... on Album {
            name,
            artist {
              id,
              first_name
            }
          }
        }
        second: node(id: "#{id2}") {
          id,
          ... on Album {
            name,
            artist {
              id,
              first_name
            }
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'first' => {
          'id' => id_for(album1),
          'name' => album1.name,
          'artist' => {
            'id' => id_for(album1.artist),
            'first_name' => album1.artist.first_name
          }
        },
        'second' => {
          'id' => id_for(album2),
          'name' => album2.name,
          'artist' => {
            'id' => id_for(album2.artist),
            'first_name' => album2.artist.first_name
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album1.id}')),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN ('#{album1.artist.id}')) ORDER BY "artists"."id"),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album2.id}')),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN ('#{album2.artist.id}')) ORDER BY "artists"."id"),
    ]
  end

  it "should support aliases for multiple invocations of the same attribute" do
    id = id_for(album1)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name1: name,
            name2: name,
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id_for(album1),
          'name1' => album1.name,
          'name2' => album1.name,
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album1.id}')),
    ]
  end

  it "should support aliases for multiple invocations of the same connection" do
    id = id_for(album1)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            first_half: tracks(first: 5) { edges { node { id, name } } }
            last_half:  tracks(last: 5)  { edges { node { id, name } } }
          }
        }
      }
    GRAPHQL

    tracks = album1.tracks.sort_by(&:created_at)
    first_half = tracks[0..4]
    last_half  = tracks[5..9]

    assert_result \
      'data' => {
        'node' => {
          'id' => id_for(album1),
          'first_half' => {
            'edges' => first_half.map { |t|
              {
                'node' => {
                  'id' => id_for(t),
                  'name' => t.name,
                }
              }
            }
          },
          'last_half' => {
            'edges' => last_half.map { |t|
              {
                'node' => {
                  'id' => id_for(t),
                  'name' => t.name,
                }
              }
            }
          },
        }
      }

    assert_sqls [
      %(SELECT "albums"."id" FROM "albums" WHERE ("albums"."id" = '#{album1.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album1.id}')) ORDER BY "created_at" LIMIT 5),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album1.id}')) ORDER BY "created_at" DESC LIMIT 5),
    ]
  end
end
