# frozen_string_literal: true

require 'spec_helper'

class ManyToOneAssociationSpec < PrelaySpec
  it "should support fetching an associated item through a many-to-one association" do
    artist = Artist.exclude(genre_id: nil).first!

    id = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            name,
            genre {
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
          'name' => artist.name,
          'genre' => {
            'id' => encode("Genre", artist.genre.id),
            'name' => artist.genre.name
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."name", "artists"."genre_id" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id"),
      %(SELECT "genres"."id", "genres"."name" FROM "genres" WHERE ("genres"."id" IN ('#{artist.genre_id}')) ORDER BY "genres"."id")
    ]
  end

  it "should support attempting to fetch an associated item through a many-to-one association when one does not exist" do
    artist = Artist.where(genre_id: nil).first!

    id = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            name,
            genre {
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
          'name' => artist.name,
          'genre' => nil,
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."name", "artists"."genre_id" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id")
    ]
  end
end
