# frozen_string_literal: true

require 'spec_helper'

class NodesQuerySpec < PrelaySpec
  let(:album)  { Album.first  }
  let(:track)  { Track.first  }
  let(:artist) { Artist.first }

  it "should support refetching multiple nodes by their relay ids" do
    id1 = id_for(album)
    id2 = id_for(track)
    id3 = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        nodes(ids: ["#{id1}", "#{id2}", "#{id3}"]) {
          id,
          __typename,
          ... on Album  { name, high_quality }
          ... on Artist { first_name, upvotes }
          ... on Track  { name, number }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'nodes' => [
          {
            'id'           => id1,
            '__typename'   => "Album",
            'name'         => album.name,
            'high_quality' => album.high_quality,
          },
          {
            'id'           => id2,
            '__typename'   => "Track",
            'name'         => track.name,
            'number'       => track.number,
          },
          {
            'id'           => id3,
            '__typename'   => "Artist",
            'first_name'   => artist.first_name,
            'upvotes'      => artist.upvotes,
          },
        ]
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."high_quality" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."number" FROM "tracks" WHERE ("tracks"."id" = '#{track.id}')),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}')),
    ]
  end

  it "should handle interfaces in a nodes query" do
    # Once this is fixed it can replace the above one.
    skip "File an issue with the GraphQL gem?"

    id1 = id_for(album)
    id2 = id_for(track)
    id3 = id_for(artist)

    execute_query <<-GRAPHQL
      query Query {
        nodes(ids: ["#{id1}", "#{id2}", "#{id3}"]) {
          id,
          __typename,
          ... on Album   { name, high_quality }
          ... on Artist  { first_name, upvotes }
          ... on Track   { name, number }
          ... on Release { name, popularity }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'nodes' => [
          {
            'id'           => id1,
            '__typename'   => "Album",
            'name'         => album.name,
            'high_quality' => album.high_quality,
            'popularity'   => album.popularity,
          },
          {
            'id'           => id2,
            '__typename'   => "Track",
            'name'         => track.name,
            'number'       => track.number,
          },
          {
            'id'           => id3,
            '__typename'   => "Artist",
            'first_name'   => artist.first_name,
            'upvotes'      => artist.upvotes,
          },
        ]
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."high_quality" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."number" FROM "tracks" WHERE ("tracks"."id" = '#{track.id}') ORDER BY "tracks"."id"),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id"),
    ]
  end

  it "when a record no longer exists should return an array containing NULL" do
    skip "Doesn't seem to be supported by the GraphQL gem? It wants a type for NULL."
  end

  it "should retrieve multiple records of the same type in the same query" do
    skip "Optimization"
  end
end
