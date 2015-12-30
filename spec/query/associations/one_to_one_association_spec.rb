require 'spec_helper'

class OneToOneAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

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

  it "should support attempting to fetch an associated item through a one-to-one association when it does not exist" do
    id = encode 'Album', album.id

    album.publisher_dataset.delete

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
            'publisher' => nil
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
