# frozen_string_literal: true

require 'spec_helper'

class OneToManyInterfaceAssociationSpec < PrelaySpec
  it "should support fetching associated items through a one-to-many association to an interface" do
    artist = Artist.first!

    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            name,
            releases(first: 200) {
              edges {
                node {
                  __typename,
                  id,
                  upvotes,
                  ... on Album {
                    name
                  },
                  ... on Compilation {
                    high_quality
                  },
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
          'name' => artist.name,
          'releases' => {
            'edges' => (artist.albums + artist.compilations).sort_by(&:release_date).reverse.map { |r|
              {
                'node' => (
                  case r
                  when Album
                    {
                      '__typename' => "Album",
                      'id' => id_for(r),
                      'upvotes' => r.upvotes,
                      'name' => r.name,
                    }
                  when Compilation
                    {
                      '__typename' => "Compilation",
                      'id' => id_for(r),
                      'upvotes' => r.upvotes,
                      'high_quality' => r.high_quality,
                    }
                  else
                    raise "Bad!"
                  end
                )
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."upvotes", "albums"."artist_id", "albums"."release_date" AS "cursor" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "release_date" DESC LIMIT 200),
      %(SELECT "compilations"."id", "compilations"."upvotes", "compilations"."high_quality", "compilations"."artist_id", "compilations"."release_date" AS "cursor" FROM "compilations" WHERE ("compilations"."artist_id" IN ('#{artist.id}')) ORDER BY "release_date" DESC LIMIT 200),
    ]
  end

  it "should limit items appropriately"
end
