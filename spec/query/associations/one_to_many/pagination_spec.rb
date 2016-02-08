# frozen_string_literal: true

require 'spec_helper'

class OneToManyPaginationSpec < PrelaySpec
  let(:artist) { Artist.first }
  let(:albums) { artist.albums.sort_by(&:release_date).reverse }

  it "should raise an error if a connection is requested without a first or last argument" do
    artist_id = id_for(artist)

    assert_invalid_query \
      "Tried to access the connection 'albums' without a 'first' or 'last' argument.",
      <<-GRAPHQL
        query Query {
          node(id: "#{artist_id}") {
            id,
            ... on Artist {
              name,
              albums {
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
  end

  # Individually spec each possible mix of pagination options.
  [true, false].each do |paginating_forward|
    [true, false].each do |all_records_requested|
      [true, false].each do |cursor_passed|
        [true, false].each do |cursor_requested|
          [true, false].each do |has_next_page_passed|
            [true, false].each do |has_previous_page_passed|
              desc = "paginating #{paginating_forward ? 'forward' : 'backward'} requesting #{all_records_requested ? 'all' : 'some'} records #{cursor_requested ? 'and' : 'but not'} their cursors with#{'out' unless cursor_passed} a cursor to page from #{'and hasNextPage' if has_next_page_passed} #{'and hasPreviousPage' if has_previous_page_passed}"

              page_info_query =
                if has_next_page_passed || has_previous_page_passed
                  <<-PAGEINFO
                    pageInfo {
                      #{'hasNextPage'     if has_next_page_passed}
                      #{'hasPreviousPage' if has_previous_page_passed}
                    }
                  PAGEINFO
                end

              page_info =
                if has_next_page_passed || has_previous_page_passed
                  r = {}
                  if has_next_page_passed
                    r['hasNextPage'] = paginating_forward ? !all_records_requested : cursor_passed
                  end
                  if has_previous_page_passed
                    r['hasPreviousPage'] = paginating_forward ? cursor_passed : !all_records_requested
                  end
                  r
                end

              args_and_expected_albums = proc do |all_albums|
                expected_albums = all_albums
                expected_albums = expected_albums.reverse unless paginating_forward

                args = {}
                args[paginating_forward ? :first : :last  ] = all_records_requested ? 10 : 3
                args[paginating_forward ? :after : :before] = to_cursor(expected_albums[1].release_date) if cursor_passed

                expected_albums = expected_albums[2..-1] if cursor_passed
                expected_albums = expected_albums[0..2] unless all_records_requested
                expected_albums = expected_albums.reverse unless paginating_forward

                [args, expected_albums]
              end

              it "on a one-to-many association should support #{desc}" do
                artist_id = id_for(artist)

                # Will need to update the spec logic if this changes.
                assert_equal 10, albums.length

                args, expected_albums = args_and_expected_albums.call(albums)

                graphql =
                  <<-GRAPHQL
                    query Query {
                      node(id: "#{artist_id}") {
                        id,
                        ... on Artist {
                          name,
                          albums(#{graphql_args(args)}) {
                            edges {
                              #{'cursor,' if cursor_requested}
                              node {
                                id,
                                name
                              }
                            }
                            #{page_info_query}
                          }
                        }
                      }
                    }
                  GRAPHQL

                execute_query(graphql)

                expectation = {
                  'edges' => expected_albums.map { |a|
                    h = {'node' => {'id' => id_for(a), 'name' => a.name}}
                    h['cursor'] = to_cursor(a.release_date) if cursor_requested
                    h
                  }
                }

                expectation['pageInfo'] = page_info if page_info

                assert_result \
                  'data' => {
                    'node' => {
                      'id' => id_for(artist),
                      'name' => artist.name,
                      'albums' => expectation,
                    }
                  }
              end
            end
          end
        end
      end
    end
  end
end
