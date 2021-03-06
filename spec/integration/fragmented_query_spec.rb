# frozen_string_literal: true

require 'spec_helper'

class FragmentedQuerySpec < PrelaySpec
  let(:album) { Album.order{random{}}.first! }

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
                first_name,
                upvotes,
                active,
              }
              tracks(first: 50) {
                edges {
                  cursor
                  node {
                    id,
                    name,
                    number,
                    high_quality,
                  }
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
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
            tracks(first: 50) {
              edges {
                node {
                  id,
                  number,
                  high_quality,
                }
              }
              pageInfo {
                hasPreviousPage
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
            tracks(first: 50) {
              edges {
                cursor
                node {
                  id,
                  name,
                }
              }
              pageInfo {
                hasNextPage
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
              first_name,
            }
          }
        }
      GRAPHQL
    ),
    fragment_on_type_at_node_level: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ...__RelayQueryFragment0kyloren
            ...__RelayQueryFragment0hansolo
            ...__RelayQueryFragment0bb8
          }
        }

        fragment __RelayQueryFragment0hansolo on Album {
          id,
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                number,
                high_quality,
              }
            }
            pageInfo {
              hasPreviousPage
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Album {
          high_quality,
          artist {
            id,
            upvotes,
            active,
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Album {
          name,
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                name,
              }
            }
            pageInfo {
              hasNextPage
            }
          }
        }

        fragment __RelayQueryFragment0poedameron on Album {
          upvotes,
          artist {
            id,
            first_name,
          }
        }

        fragment __RelayQueryFragment0kyloren on Track {
          number,
          high_quality
        }
      GRAPHQL
    ),
    fragment_on_interface_at_node_level: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            id,
            ...__RelayQueryFragment0kyloren
            ...__RelayQueryFragment0hansolo
            ...__RelayQueryFragment0bb8
          }
        }

        fragment __RelayQueryFragment0hansolo on Album {
          id,
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                number,
                high_quality,
              }
            }
            pageInfo {
              hasPreviousPage
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Release {
          high_quality,
          artist {
            id,
            upvotes,
            active,
          }
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on Release {
          name,
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                name,
              }
            }
            pageInfo {
              hasNextPage
            }
          }
        }

        fragment __RelayQueryFragment0poedameron on Album {
          upvotes,
          artist {
            id,
            first_name,
          }
        }

        fragment __RelayQueryFragment0kyloren on Track {
          number,
          high_quality
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
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
              }
            }
            pageInfo {
              hasPreviousPage
            }
          }
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on Album {
          id,
          name,
          artist {
            id,
            first_name,
          }
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                name,
              }
              cursor
            }
            pageInfo {
              hasNextPage
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
          tracks(first: 50) {
            edges {
              cursor
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
          tracks(first: 50) {
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
              tracks(first: 50) {
                edges {
                  cursor
                  node {
                    id,
                    name,
                    number,
                    high_quality,
                  }
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
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
          first_name,
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
                first_name,
                upvotes,
                active,
              }
              tracks(first: 50) {
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
          pageInfo {
            hasPreviousPage
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
          pageInfo {
            hasNextPage
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
            cursor
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
                first_name,
                upvotes,
                active,
              }
              tracks(first: 50) {
                edges {
                  ...__RelayQueryFragment0hansolo
                  ...__RelayQueryFragment0bb8
                }
                pageInfo {
                  hasPreviousPage
                  hasNextPage
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on TrackEdge {
          cursor
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
                first_name,
                upvotes,
                active,
              }
              tracks(first: 50) {
                edges {
                  cursor
                  node {
                    ...__RelayQueryFragment0hansolo
                    ...__RelayQueryFragment0bb8
                  }
                }
                pageInfo {
                  hasPreviousPage
                  hasNextPage
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
    fragment_inside_page_info: (
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
                first_name,
                upvotes,
                active,
              }
              tracks(first: 50) {
                edges {
                  cursor
                  node {
                    id,
                    name,
                    number,
                    high_quality,
                  }
                }
                pageInfo {
                  ...__RelayQueryFragment0hansolo
                  ...__RelayQueryFragment0bb8
                }
              }
            }
          }
        }

        fragment __RelayQueryFragment0hansolo on PageInfo {
          hasPreviousPage
          ...__RelayQueryFragment0rey
        }

        fragment __RelayQueryFragment0bb8 on PageInfo {
          hasNextPage
          ...__RelayQueryFragment0poedameron
        }

        fragment __RelayQueryFragment0rey on PageInfo {
          hasNextPage
        }

        fragment __RelayQueryFragment0poedameron on PageInfo {
          hasNextPage
          hasNextPage
        }
      GRAPHQL
    ),
    deeply_nested_fragments: (
      <<-GRAPHQL
        query Query {
          node(id: "%{id}") {
            ...__RelayQueryFragment0hansolo
            id
          }
        }

        fragment __RelayQueryFragment0hansolo on Node {
          id,
          ... on Album {
            name,
            ...__RelayQueryFragment0bb8
            upvotes,
          }
        }

        fragment __RelayQueryFragment0bb8 on Album {
          upvotes,
          high_quality,
          artist {
            id,
            ...__RelayQueryFragment0rey
          }
          tracks(first: 50) {
            edges {
              cursor
              node {
                id,
                name,
                ...__RelayQueryFragment0poedameron
              }
            }
            pageInfo {
              hasNextPage
              hasPreviousPage
            }
          }
        }

        fragment __RelayQueryFragment0rey on Artist {
          first_name,
          upvotes,
          active,
        }

        fragment __RelayQueryFragment0poedameron on Track {
          name,
          number,
          high_quality,
        }
      GRAPHQL
    ),
  }

  queries.each do |name, query|
    it "should handle a #{name} query" do
      execute_query(query % {id: id_for(album)})

      assert_result \
        'data' => {
          'node' => {
            'id' => id_for(album),
            'name' => album.name,
            'upvotes' => album.upvotes,
            'high_quality' => album.high_quality,
            'artist' => {
              'id' => id_for(album.artist),
              'first_name' => album.artist.first_name,
              'upvotes' => album.artist.upvotes,
              'active' => album.artist.active,
            },
            'tracks' => {
              'edges' => album.tracks.map { |track|
                {
                  'cursor' => to_cursor(track.created_at),
                  'node' => {
                    'id' => id_for(track),
                    'name' => track.name,
                    'number' => track.number,
                    'high_quality' => track.high_quality,
                  }
                }
              },
              'pageInfo' => {
                'hasNextPage' => false,
                'hasPreviousPage' => false,
              }
            }
          }
        }

      assert_sqls [
        %(SELECT "albums"."id", "albums"."name", "albums"."upvotes", "albums"."high_quality", "albums"."artist_id" FROM "albums" WHERE ("albums"."id" = '#{album.id}')),
        %(SELECT "artists"."id", "artists"."first_name", "artists"."upvotes", "artists"."active" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist_id}')) ORDER BY "id"),
        %(SELECT "tracks"."id", "tracks"."name", "tracks"."number", "tracks"."high_quality", "tracks"."release_id", "tracks"."created_at" FROM "tracks" WHERE ("tracks"."release_id" IN ('#{album.id}')) ORDER BY "created_at" LIMIT 51)
      ]
    end
  end

  it "should ignore inline fragments on the wrong type" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist {
            first_name,
            upvotes,
            active,
          }
          ... on Album {
            name,
            high_quality,
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id_for(album),
          'name' => album.name,
          'high_quality' => album.high_quality,
        }
      }
  end
end
