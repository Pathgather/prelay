# frozen_string_literal: true

require 'spec_helper'

class OneToOneAssociationSpec < PrelaySpec
  let(:album) { Album.first! }

  it "should support fetching an associated item through a one-to-one association" do
    id = id_for(album)

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
            'id' => id_for(album.publisher),
            'name' => album.publisher.name,
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "publishers"."id", "publishers"."name", "publishers"."release_id" FROM "publishers" WHERE ("publishers"."release_id" IN ('#{album.id}')) ORDER BY "id")
    ]
  end

  it "should support attempting to fetch an associated item through a one-to-one association when it does not exist" do
    id = id_for(album)

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
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "publishers"."id", "publishers"."name", "publishers"."release_id" FROM "publishers" WHERE ("publishers"."release_id" IN ('#{album.id}')) ORDER BY "id")
    ]
  end
end
