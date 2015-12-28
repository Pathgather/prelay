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
            ...__RelayQueryFragment0hansolo
          }
        }

        fragment __RelayQueryFragment0hansolo on Node {
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
      GRAPHQL
    ),
    fragment_at_node_fields_level: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ... on Album {
              ...__RelayQueryFragment0hansolo
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on Album {
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
          name,
          upvotes,
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
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on TrackConnection {
          edges {
            node {
              id,
              name,
              number,
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
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on TrackEdge {
          node {
            id,
            name,
            number,
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
                  }
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on Track {
          id,
          name,
          number,
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
