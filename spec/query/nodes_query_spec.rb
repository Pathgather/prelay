# frozen_string_literal: true

require 'spec_helper'

class NodesQuerySpec < PrelaySpec
  let(:album)  { Album.first }
  let(:track)  { Track.first }
  let(:artist) { Artist.first }

  it "should support refetching an item by its relay id" do
    id1 = encode 'Album',  album.id
    id2 = encode 'Track',  track.id
    id3 = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        nodes(ids: ["#{id1}", "#{id2}", "#{id3}"]) {
          id,
          __typename,
          ... on Album  { name, high_quality }
          ... on Artist { name, upvotes }
          ... on Track  { name, number }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'nodes' => [
          {
            'id' => id1,
            '__typename' => "Album",
            'name' => album.name,
            'high_quality' => album.high_quality,
          },
          {
            'id' => id2,
            '__typename' => "Track",
            'name' => track.name,
            'number' => track.number,
          },
          {
            'id' => id3,
            '__typename' => "Artist",
            'name' => artist.name,
            'upvotes' => artist.upvotes,
          },
        ]
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."high_quality" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
      %(SELECT "tracks"."id", "tracks"."name", "tracks"."number" FROM "tracks" WHERE ("tracks"."id" = '#{track.id}') ORDER BY "tracks"."id"),
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id"),
    ]
  end
end