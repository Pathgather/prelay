# frozen_string_literal: true

require 'spec_helper'

class FilteredOneToManyQuerySpec < PrelaySpec
  let(:artist) { Artist.first! }

  it "should support fetching associated items through a filtered one-to-many association" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
            albums(first: 50, upvotes_greater_than: 10) {
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

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'first_name' => artist.first_name,
          'albums' => {
            'edges' => artist.albums_dataset.where{upvotes > 10}.all.sort_by(&:release_date).reverse.map { |album|
              {
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE (("upvotes" > 10) AND ("albums"."artist_id" IN ('#{artist.id}'))) ORDER BY "release_date" DESC LIMIT 50)
    ]
  end
end