# frozen_string_literal: true

require 'spec_helper'

class InterfaceConnectionQuerySpec < PrelaySpec
  let :schema do
    Prelay::Schema.new(temporary: true)
  end

  let :artist_type do
    mock :type, schema: schema do
      name "Artist"
      model Artist
      attribute :first_name, "The first name of the artist", datatype: :string
    end
  end

  let :release_interface do
    at = artist_type
    mock :interface, schema: schema do
      name "Release"
      attribute :name, "The name of the release", datatype: :string
      many_to_one :artist, "The artist who made the release", nullable: false, target: at
    end
  end

  let :album_type do
    i = release_interface
    mock :type, schema: schema do
      name "Album"
      model Album
      interface i, :release_id
      attribute :name, "The name of the album", datatype: :string
      many_to_one :artist, "The artist who released the album", nullable: false
    end
  end

  let :compilation_type do
    i = release_interface
    mock :type, schema: schema do
      name "Compilation"
      model Compilation
      interface i, :release_id
      attribute :name, "The name of the compilation", datatype: :string
      many_to_one :artist, "The artist who released the album", nullable: false
    end
  end

  let :query do
    artist_type
    album_type
    compilation_type
    t = release_interface
    mock :query, schema: schema do
      include Prelay::Connection
      name "ReleasesQuery"
      description "Returns all releases in the DB."
      type t
      order Sequel.desc(:created_at)
    end
  end

  it "should support returning a connection on an interface" do
    query
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
