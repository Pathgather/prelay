# frozen_string_literal: true

require 'spec_helper'

class FilterSpec < PrelaySpec
  let(:genre)  { Genre.first  }
  let(:artist) { Artist.first }

  mock_schema do
    ReleaseInterface.class_eval do
      filter(:has_cool_name) { |ds| ds.where{char_length(:name) > 3} }
      filter(:name_greater_than, :string) { |ds, string| ds.where{name > string} }
    end

    AlbumType.class_eval do
      filter(:are_high_quality) { |ds| ds.where(:high_quality) }
      filter(:upvotes_greater_than, :integer) { |ds, count| ds.where{upvotes > count} }
    end

    query :Albums do
      include Prelay::Connection
      type AlbumType
      order :created_at
    end

    query :Releases do
      include Prelay::Connection
      type ReleaseInterface
      order :created_at
    end
  end

  it "should support filters in top-level connection queries on Types" do
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

    albums = Album.order(:created_at).where(:high_quality).limit(5).all

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
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" FROM "albums" WHERE "high_quality" ORDER BY "created_at" LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "id"),
    ]
  end

  it "should support filters in top-level connection queries on Interfaces" do
    execute_query <<-GRAPHQL
      query Query {
        connections {
          releases(first: 5, has_cool_name: true) {
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

    albums = Album.order(:created_at).where{char_length(:name) > 3}.limit(5).all
    compilations = Compilation.order(:created_at).where{char_length(:name) > 3}.limit(5).all
    releases = (albums + compilations).sort_by(&:created_at).first(5)

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

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" FROM "albums" WHERE (char_length("name") > 3) ORDER BY "created_at" LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{albums.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "id"),
      %(SELECT "compilations"."id", "compilations"."name", "compilations"."artist_id", "compilations"."created_at" FROM "compilations" WHERE (char_length("name") > 3) ORDER BY "created_at" LIMIT 5),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN (#{compilations.map{|a| "'#{a.artist_id}'"}.uniq.join(', ')})) ORDER BY "id"),
    ]
  end

  it "should support filters in one_to_many connections against types" do
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
            'edges' => artist.albums_dataset.where{upvotes > 10}.first(5).map { |album|
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
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" WHERE (("upvotes" > 10) AND ("albums"."artist_id" IN ('#{artist.id}'))) ORDER BY "created_at" LIMIT 5)
    ]
  end

  it "should support filters in one_to_many connections against interfaces" do
    id = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
            releases(first: 5, has_cool_name: true) {
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

    albums = artist.albums_dataset.order(:created_at).where{char_length(:name) > 3}.first(5)
    compilations = artist.compilations_dataset.order(:created_at).where{char_length(:name) > 3}.first(5)
    releases = (albums + compilations).sort_by(&:created_at).first(5)

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'first_name' => artist.first_name,
          'releases' => {
            'edges' => releases.map { |release|
              {
                'node' => {
                  'id' => id_for(release),
                  'name' => release.name,
                }
              }
            }
          }
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at" FROM "albums" WHERE ((char_length("name") > 3) AND ("albums"."artist_id" IN ('#{artist.id}'))) ORDER BY "created_at" LIMIT 5),
      %(SELECT "compilations"."id", "compilations"."name", "compilations"."artist_id", "compilations"."created_at" FROM "compilations" WHERE ((char_length("name") > 3) AND ("compilations"."artist_id" IN ('#{artist.id}'))) ORDER BY "created_at" LIMIT 5)
    ]
  end

  it "should support filters in nested one_to_many connections on Types" do
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

    artists = genre.artists_dataset.first(5)

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
                    'edges' => artist.albums_dataset.where{upvotes > 10}.first(5).map { |album|
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
      %(SELECT "artists"."first_name", "artists"."id", "artists"."genre_id" FROM "artists" WHERE ("artists"."genre_id" IN ('#{genre.id}')) ORDER BY "created_at" LIMIT 5),
      %(SELECT * FROM (SELECT "albums"."id", "albums"."name", "albums"."artist_id", row_number() OVER (PARTITION BY "albums"."artist_id" ORDER BY "created_at") AS "prelay_row_number" FROM "albums" WHERE (("upvotes" > 10) AND ("albums"."artist_id" IN (#{artists.map{|a| "'#{a.id}'"}.join(', ')})))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end

  it "should support filters in nested one_to_many connections on Interfaces" do
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
                  releases(first: 5, name_greater_than: "p") {
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

    artists = genre.artists_dataset.order(:created_at).first(5)

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => genre.name,
          'artists' => {
            'edges' => artists.map { |artist|
              albums = artist.albums_dataset.order(:created_at).where{name > 'p'}.first(5)
              compilations = artist.compilations_dataset.order(:created_at).where{name > 'p'}.first(5)
              releases = (albums + compilations).sort_by(&:created_at).first(5)

              {
                'node' => {
                  'first_name' => artist.first_name,
                  'releases' => {
                    'edges' => releases.map { |release|
                      {
                        'node' => {
                          'id' => id_for(release),
                          'name' => release.name,
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
      %(SELECT "artists"."first_name", "artists"."id", "artists"."genre_id" FROM "artists" WHERE ("artists"."genre_id" IN ('#{genre.id}')) ORDER BY "created_at" LIMIT 5),
      %(SELECT * FROM (SELECT "albums"."id", "albums"."name", "albums"."artist_id", "albums"."created_at", row_number() OVER (PARTITION BY "albums"."artist_id" ORDER BY "created_at") AS "prelay_row_number" FROM "albums" WHERE (("name" > 'p') AND ("albums"."artist_id" IN (#{artists.map{|a| "'#{a.id}'"}.join(', ')})))) AS "t1" WHERE ("prelay_row_number" <= 5)),
      %(SELECT * FROM (SELECT "compilations"."id", "compilations"."name", "compilations"."artist_id", "compilations"."created_at", row_number() OVER (PARTITION BY "compilations"."artist_id" ORDER BY "created_at") AS "prelay_row_number" FROM "compilations" WHERE (("name" > 'p') AND ("compilations"."artist_id" IN (#{artists.map{|a| "'#{a.id}'"}.join(', ')})))) AS "t1" WHERE ("prelay_row_number" <= 5)),
    ]
  end
end
