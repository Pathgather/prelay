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
              artist {
                id,
                name
              }
              tracks {
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
            artist {
              id,
              name
            }
            tracks {
              edges {
                node {
                  id,
                  name
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
          artist {
            id,
            name
          }
          tracks {
            edges {
              node {
                id,
                name
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
              artist {
                ...__RelayQueryFragment0hansolo
              }
              tracks {
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

        fragment __RelayQueryFragment0hansolo on Artist {
          id,
          name
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
              artist {
                id,
                name
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
              name
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
              artist {
                id,
                name
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
            name
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
              artist {
                id,
                name
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
          name
        }
      GRAPHQL
    ),
  }

  queries.each do |name, query|
    it "should handle a #{name} query" do
      skip if [:fragment_inside_association_connection, :fragment_inside_association_edge].include?(name)

      result = execute_query(query % {id: encode('Album', album.id)})

      expected = {
        'data' => {
          'node' => {
            'id' => encode('Album', album.id),
            'name' => album.name,
            'artist' => {
              'id' => encode('Artist', album.artist.id),
              'name' => album.artist.name,
            },
            'tracks' => {
              'edges' => album.tracks.sort_by(&:id).map { |track|
                {
                  'node' => {
                    'id' => encode('Track', track.id),
                    'name' => track.name,
                  }
                }
              }
            }
          }
        }
      }

      assert_equal expected, result
    end
  end
end
