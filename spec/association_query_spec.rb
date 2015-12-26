require 'spec_helper'

class AssociationQuerySpec < PrelaySpec
  def execute_query(graphql)
    GraphQLSchema.execute(graphql, debug: true)
  end

  def execute_invalid_query(graphql)
    assert_raises(Prelay::InvalidGraphQLQuery) { execute_query(graphql) }
  end

  def encode(type, id)
    Base64.strict_encode64 "#{type}:#{id}"
  end

  it "should support fetching an associated item through a many-to-one association" do
    id = encode 'Album', TEST_ALBUM.id

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

    assert_equal({'data' => {'node' => {'id' => id, 'name' => TEST_ALBUM.name, 'artist' => {'id' => encode("Artist", TEST_ARTIST.id), 'name' => TEST_ARTIST.name}}}}, result)

    assert_equal [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{TEST_ALBUM.id}') ORDER BY "albums"."id"),
      %(SELECT "artists"."id", "artists"."name" FROM "artists" WHERE ("artists"."id" IN ('#{TEST_ALBUM.artist_id}')) ORDER BY "artists"."id")
    ], $sqls
  end

  it "should support fetching an associated item through a one-to-many association" do
    id = encode 'Album', TEST_ALBUM.id

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
            'name' => TEST_ALBUM.name,
            'tracks' => {
              'edges' => TEST_TRACKS.sort_by(&:id).map { |track|
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
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{TEST_ALBUM.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{TEST_ALBUM.id}')) ORDER BY "tracks"."id")
    ], $sqls
  end

  it "should support fetching an associated item through a one-to-one association" do
    id = encode 'Album', TEST_ALBUM.id

    result = execute_query <<-GRAPHQL
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

    first_track = TEST_TRACKS.find{|t| t.number == 1}

    assert_equal(
      {
        'data' => {
          'node' => {
            'id' => id,
            'name' => TEST_ALBUM.name,
            'first_track' => {
              'id' => encode('Track', first_track.id),
              'name' => first_track.name,
            }
          }
        }
      },
      result
    )

    assert_equal [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{TEST_ALBUM.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."album_id" FROM "tracks" WHERE (("number" = 1) AND ("tracks"."album_id" IN ('#{TEST_ALBUM.id}'))) ORDER BY "tracks"."id")
    ], $sqls
  end
end
