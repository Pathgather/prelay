require 'spec_helper'

class AssociationQuerySpec < PrelaySpec
  let(:album)  { ::Album.first! }
  let(:artist) { album.artist }

  it "should support fetching an associated item through a many-to-one association" do
    id = encode 'Album', album.id

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            artist {
              id,
              name
            }
          }
        }
      }
    GRAPHQL

    assert_equal({'data' => {'node' => {'id' => id, 'name' => album.name, 'artist' => {'id' => encode("Artist", artist.id), 'name' => artist.name}}}}, result)

    assert_equal [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "artists"."id", "artists"."name" FROM "artists" WHERE ("artists"."id" IN ('#{artist.id}')) ORDER BY "artists"."id")
    ], sqls
  end

  it "should support fetching an associated item through a one-to-many association" do
    id = encode 'Album', album.id

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks {
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

    assert_equal(
      {
        'data' => {
          'node' => {
            'id' => id,
            'name' => album.name,
            'tracks' => {
              'edges' => album.tracks.sort_by(&:id).map { |track|
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
      },
      result
    )

    assert_equal [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "tracks"."id")
    ], sqls
  end

  it "should support fetching an associated item through a one-to-one association" do
    id = encode 'Album', album.id

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            publisher {
              id,
              name
            }
          }
        }
      }
    GRAPHQL

    assert_equal(
      {
        'data' => {
          'node' => {
            'id' => id,
            'name' => album.name,
            'publisher' => {
              'id' => encode('Publisher', album.publisher.id),
              'name' => album.publisher.name,
            }
          }
        }
      },
      result
    )

    assert_equal [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "publishers"."id", "publishers"."name", "publishers"."album_id" FROM "publishers" WHERE ("publishers"."album_id" IN ('#{album.id}')) ORDER BY "publishers"."id")
    ], sqls
  end
end
