# frozen_string_literal: true

require 'spec_helper'

class InterfaceConnectionQuerySpec < PrelaySpec
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
                  name
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
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
      %(SELECT "compilations"."id", "compilations"."name", "compilations"."artist_id", "compilations"."created_at" AS "cursor" FROM "compilations" ORDER BY "created_at" DESC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" IN (#{compilations.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'connections' => {
          'releases' => {
            'edges' => releases.map { |release|
              {
                'cursor' => to_cursor(release.created_at),
                'node' => {
                  'id' => encode(release.is_a?(Album) ? 'Album' : 'Compilation', release.id),
                  'name' => release.name,
                  'artist' => {
                    'id' => encode('Artist', release.artist_id),
                    'name' => release.artist.name,
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
