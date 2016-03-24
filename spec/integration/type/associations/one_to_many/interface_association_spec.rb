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
            first_name,
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
          'first_name' => artist.first_name,
          'releases' => {
            'edges' => artist.releases.map { |r|
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
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."upvotes", "albums"."artist_id", "albums"."created_at" AS "cursor" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at" LIMIT 200),
      %(SELECT "compilations"."id", "compilations"."upvotes", "compilations"."high_quality", "compilations"."artist_id", "compilations"."created_at" AS "cursor" FROM "compilations" WHERE ("compilations"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at" LIMIT 200),
    ]
  end

  it "should support fetching associated items through a one-to-many association to an interface when only a subset of types are necessary" do
    assert_instance_of Prelay::Type::Association, ArtistType.associations.delete(:releases)
    ArtistType.one_to_many :releases, "Albums and Compilations released by the artist", order: :created_at, target: ReleaseInterface, foreign_key: :artist_id, target_types: [AlbumType]

    artist = Artist.first!

    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
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
          'first_name' => artist.first_name,
          'releases' => {
            'edges' => artist.albums.map { |a|
              {
                'node' => {
                  '__typename' => "Album",
                  'id' => id_for(a),
                  'upvotes' => a.upvotes,
                  'name' => a.name,
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."upvotes", "albums"."artist_id" FROM "albums" WHERE ("albums"."artist_id" IN ('#{artist.id}')) ORDER BY "created_at" LIMIT 200),
    ]
  end

  it "should limit items appropriately"
end
