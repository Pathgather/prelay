# frozen_string_literal: true

require 'spec_helper'

class FilterSpec < PrelaySpec
  let(:genre)  { Genre.first  }
  let(:artist) { Artist.first }

  mock_schema do
    type :Album do
      string :name

      many_to_one :artist, nullable: false

      filter(:are_high_quality) { |ds| ds.where(:high_quality) }
      filter(:upvotes_greater_than, :integer) { |ds, count| ds.where{upvotes > count} }
    end

    type :Artist do
      string :first_name
      one_to_many :albums
    end

    type :Genre do
      string :name
      one_to_many :artists
    end

    query :Albums do
      include Prelay::Connection
      type :Album
      order Sequel.desc(:created_at)
    end
  end

  it "should support filters in top-level connection queries" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          albums(first: 5, are_high_quality: true) {
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

    albums = Album.order(Sequel.desc(:created_at)).where(:high_quality).limit(5).all

    assert_result \
      'data' => {
        'connections' => {
          'albums' => {
            'edges' => albums.map { |album|
              {
                'cursor' => to_cursor(album.created_at),
                'node' => {
                  'id' => id_for(album),
                  'name' => album.name,
                  'artist' => {
                    'id' => id_for(album.artist),
                    'first_name' => album.artist.first_name,
                  }
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" AS "cursor" FROM "albums" WHERE "high_quality" ORDER BY "created_at" DESC LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "artists"."id"),
    ]
  end

  it "should support filters in one_to_many connections" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
            albums(first: 5, upvotes_greater_than: 10) {
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
            'edges' => artist.albums_dataset.where{upvotes > 10}.sort_by(&:release_date).reverse.first(5).map { |album|
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
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE (("upvotes" > 10) AND ("albums"."artist_id" IN ('#{artist.id}'))) ORDER BY "release_date" DESC LIMIT 5)
    ]
  end

  it "should support filters in nested one_to_many connections" do
    id = id_for(genre)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Genre {
            name,
            artists(first: 5) {
              edges {
                node {
                  first_name,
                  albums(first: 5, upvotes_greater_than: 10) {
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
          }
        }
      }
    GRAPHQL

    artists = genre.artists_dataset.order(:id).first(5)

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => genre.name,
          'artists' => {
            'edges' => artists.map { |artist|
              {
                'node' => {
                  'first_name' => artist.first_name,
                  'albums' => {
                    'edges' => artist.albums_dataset.where{upvotes > 10}.all.sort_by(&:release_date).reverse.first(5).map { |album|
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
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "genres"."id", "genres"."name" FROM "genres" WHERE ("genres"."id" = '#{genre.id}')),
      %(SELECT "artists"."first_name", "artists"."id", "artists"."genre_id" FROM "artists" WHERE ("artists"."genre_id" IN ('#{genre.id}')) ORDER BY "artists"."id" LIMIT 5),
      %(SELECT * FROM (SELECT "albums"."id", "albums"."name", "albums"."artist_id", row_number() OVER (PARTITION BY "albums"."artist_id" ORDER BY "release_date" DESC) AS "prelay_row_number" FROM "albums" WHERE (("upvotes" > 10) AND ("albums"."artist_id" IN (#{artists.map{|a| "'#{a.id}'"}.join(', ')})))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end
end