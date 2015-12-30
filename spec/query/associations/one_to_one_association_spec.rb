require 'spec_helper'

class OneToOneAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support fetching an associated item through a one-to-one association" do
    id = encode 'Album', album.id

    execute_query <<-GRAPHQL
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

    assert_result \
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

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "publishers"."id", "publishers"."name", "publishers"."album_id" FROM "publishers" WHERE ("publishers"."album_id" IN ('#{album.id}')) ORDER BY "publishers"."id")
    ]
  end

  it "should support attempting to fetch an associated item through a one-to-one association when it does not exist" do
    id = encode 'Album', album.id

    album.publisher_dataset.delete

    execute_query <<-GRAPHQL
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

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => album.name,
          'publisher' => nil
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "publishers"."id", "publishers"."name", "publishers"."album_id" FROM "publishers" WHERE ("publishers"."album_id" IN ('#{album.id}')) ORDER BY "publishers"."id")
    ]
  end
end
