# frozen_string_literal: true

require 'spec_helper'

class OneToManyInterfaceAssociationSpec < PrelaySpec
  it "should support fetching associated items through a one-to-many association to an interface" do
    skip "Not yet supported"

    artist = Artist.first!

    id = encode 'Artist', artist.id

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
              case r
              when Album
                {
                  '__typename' => "Album",
                  'id' => encode("Album", r.id),
                  'upvotes' => r.upvotes,
                  'name' => r.name,
                }
              when Compilation
                {
                  '__typename' => "Compilation",
                  'id' => encode("Compilation", r.id),
                  'upvotes' => r.upvotes,
                  'high_quality' => r.high_quality,
                }
              else
                raise "Bad!"
              end
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."release_id" FROM "tracks" WHERE ("tracks"."id" = '#{track.id}')),
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" IN ('#{track.release_id}')) ORDER BY "id"),
      %(SELECT "compilations"."id", "compilations"."name" FROM "compilations" WHERE ("compilations"."id" IN ('#{track.release_id}')) ORDER BY "id"),
    ]
  end
end
