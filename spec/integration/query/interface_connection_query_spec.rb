# frozen_string_literal: true

require 'spec_helper'

class InterfaceConnectionQuerySpec < PrelaySpec
  mock_schema do
    a = type :Artist do
      string :first_name
    end

    i = interface :Release do
      string :name
      many_to_one :artist, nullable: false, target: a
    end

    type :Album do
      interface i, :release_id
      string :name
      many_to_one :artist, nullable: false
    end

    type :Compilation do
      interface i, :release_id
      string :name
      many_to_one :artist, nullable: false
    end

    query :Releases do
      include Prelay::Connection
      type :Release
      order Sequel.desc(:created_at)
    end
  end

  it "should support returning a connection on an interface" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          releases(first: 5) {
            edges {
              cursor
              node {
                id,
                name,
                artist {
                  id,
                  first_name
                }
              }
            }
          }
        }
      }
    GRAPHQL

    albums = Album.order(Sequel.desc(:created_at)).limit(5).all
    compilations = Compilation.order(Sequel.desc(:created_at)).limit(5).all
    releases = (albums + compilations).sort_by(&:created_at).reverse.first(5)

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" AS "cursor" FROM "albums" ORDER BY "created_at" DESC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
      %(SELECT "compilations"."id", "compilations"."name", "compilations"."artist_id", "compilations"."created_at" AS "cursor" FROM "compilations" ORDER BY "created_at" DESC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{compilations.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'connections' => {
          'releases' => {
            'edges' => releases.map { |release|
              {
                'cursor' => to_cursor(release.created_at),
                'node' => {
                  'id' => id_for(release),
                  'name' => release.name,
                  'artist' => {
                    'id' => id_for(release.artist),
                    'first_name' => release.artist.first_name,
                  }
                }
              }
            }
          }
        }
      }
  end

  it "should support filters on the given interface"
end
