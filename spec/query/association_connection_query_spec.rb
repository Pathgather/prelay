require 'spec_helper'

class ConnectionQuerySpec < PrelaySpec
  let(:album) { ::Album.first! }

  it "should support fetching associated items through a one-to-many association" do
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

  it "should require an 'edges' field on a connection" do
    id = encode 'Album', album.id

    result = execute_invalid_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks {
              pageInfo {
                hasNextPage
              }
            }
          }
        }
      }
    GRAPHQL

    assert_equal "can't specify a Relay connection without an 'edges' field", result.message
  end

  it "should require a 'node' field on an edge" do
    id = encode 'Album', album.id

    result = execute_invalid_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album {
            name,
            tracks {
              edges {
                cursor
              }
            }
          }
        }
      }
    GRAPHQL

    assert_equal "can't specify a Relay edge without a 'node' field", result.message
  end
end
