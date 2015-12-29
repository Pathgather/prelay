require 'spec_helper'

class FragmentedQuerySpec < PrelaySpec
  let(:album) { ::Album.first! }

  queries = {
    control: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              name,
              upvotes,
              high_quality,
              artist {
                id,
                name,
                upvotes,
                active,
              }
              tracks {
                edges {
                  node {
                    id,
                    name,
                    number,
                    high_quality,
                  }
                }
              }
            }
          }
        }
      GRAPHQL
    ),
    fragment_at_node_level: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ...__RelayQueryFragment0hansolo
            ...__RelayQueryFragment0bb8
          }
        }

        fragment __RelayQueryFragment0hansolo on Node {
          id,
          ... on Album {
            id,
            tracks {
              edges {
                node {
                  id,
                  number,
                  high_quality,
                }
              }
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Node {
          id,
          ... on Album {
            id,
            high_quality,
            artist {
              id,
              upvotes,
              active,
            }
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Node {
          id,
          ... on Album {
            id,
            name,
            tracks {
              edges {
                node {
                  id,
                  name,
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0poedameron on Node {
          id,
          ... on Album {
            id,
            upvotes,
            artist {
              id,
              name,
            }
          }
        }
      GRAPHQL
    ),
    fragment_at_node_fields_level: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              id,
              ...__RelayQueryFragment0hansolo
              ...__RelayQueryFragment0bb8
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on Album {
          id,
          artist {
            id,
          }
          tracks {
            edges {
              node {
                id,
              }
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Album {
          id,
          name,
          artist {
            id,
            name,
          }
          tracks {
            edges {
              node {
                id,
                name,
              }
            }
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Album {
          id,
          upvotes,
          artist {
            id,
            upvotes,
          }
          tracks {
            edges {
              node {
                id,
                number,
              }
            }
          }
        }

        fragment __RelayQueryFragment0poedameron on Album {
          id,
          high_quality,
          artist {
            id,
            active,
          }
          tracks {
            edges {
              node {
                id,
                high_quality,
              }
            }
          }
        }
      GRAPHQL
    ),
    fragment_inside_association_field: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              name,
              upvotes,
              high_quality,
              artist {
                ...__RelayQueryFragment0hansolo
                ...__RelayQueryFragment0bb8
              }
              tracks {
                edges {
                  node {
                    id,
                    name,
                    number,
                    high_quality,
                  }
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on Artist {
          id,
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Artist {
          id,
          name,
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Artist {
          id,
          upvotes,
        }

        fragment __RelayQueryFragment0poedameron on Artist {
          id,
          active,
        }
      GRAPHQL
    ),
    fragment_inside_association_connection: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              name,
              upvotes,
              high_quality,
              artist {
                id,
                name,
                upvotes,
                active,
              }
              tracks {
                ...__RelayQueryFragment0hansolo
                ...__RelayQueryFragment0bb8
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on TrackConnection {
          edges {
            node {
              id,
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on TrackConnection {
          edges {
            node {
              id,
              name,
            }
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on TrackConnection {
          edges {
            node {
              id,
              number,
            }
          }
        }

        fragment __RelayQueryFragment0poedameron on TrackConnection {
          edges {
            node {
              id,
              high_quality,
            }
          }
        }
      GRAPHQL
    ),
    fragment_inside_association_edge: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              name,
              upvotes,
              high_quality,
              artist {
                id,
                name,
                upvotes,
                active,
              }
              tracks {
                edges {
                  ...__RelayQueryFragment0hansolo
                  ...__RelayQueryFragment0bb8
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on TrackEdge {
          node {
            id,
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on TrackEdge {
          node {
            id,
            name,
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on TrackEdge {
          node {
            id,
            number,
          }
        }

        fragment __RelayQueryFragment0poedameron on TrackEdge {
          node {
            id,
            high_quality,
          }
        }
      GRAPHQL
    ),
    fragment_inside_association_node: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              name,
              upvotes,
              high_quality,
              artist {
                id,
                name,
                upvotes,
                active,
              }
              tracks {
                edges {
                  node {
                    ...__RelayQueryFragment0hansolo
                    ...__RelayQueryFragment0bb8
                  }
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on Track {
          id,
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Track {
          id,
          name,
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Track {
          id,
          number,
        }

        fragment __RelayQueryFragment0poedameron on Track {
          id,
          high_quality,
        }
      GRAPHQL
    ),
  }

  queries.each do |name, query|
    it "should handle a #{name} query" do
      result = execute_query(query % {id: encode('Album', album.id)})

      expected = {
        'data' => {
          'node' => {
            'id' => encode('Album', album.id),
            'name' => album.name,
            'upvotes' => album.upvotes,
            'high_quality' => album.high_quality,
            'artist' => {
              'id' => encode('Artist', album.artist.id),
              'name' => album.artist.name,
              'upvotes' => album.artist.upvotes,
              'active' => album.artist.active,
            },
            'tracks' => {
              'edges' => album.tracks.sort_by(&:id).map { |track|
                {
                  'node' => {
                    'id' => encode('Track', track.id),
                    'name' => track.name,
                    'number' => track.number,
                    'high_quality' => track.high_quality,
                  }
                }
              }
            }
          }
        }
      }

      assert_equal expected, result

      assert_equal [
        %(SELECT "albums"."id", "albums"."name", "albums"."upvotes", "albums"."high_quality", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id"),
        %(SELECT "artists"."id", "artists"."name", "artists"."upvotes", "artists"."active" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist_id}')) ORDER BY "artists"."id"),
        %(SELECT "tracks"."id", "tracks"."name", "tracks"."number", "tracks"."high_quality", "tracks"."album_id" FROM "tracks" WHERE ("tracks"."album_id" IN ('#{album.id}')) ORDER BY "tracks"."id")
      ], sqls
    end
  end
end
