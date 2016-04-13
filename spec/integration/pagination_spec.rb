# frozen_string_literal: true

require 'spec_helper'

class PaginationSpec < PrelaySpec
  describe "on a one_to_many association" do
    let(:artist)   { Artist.first }
    let(:albums)   { artist.albums }
    let(:releases) { artist.releases }

    describe "against a type" do
      mock_schema do
        query :Albums do
          include Prelay::Connection
          type AlbumType
          order Sequel.asc(:created_at)
        end

        query :Releases do
          include Prelay::Connection
          type ReleaseInterface
          order Sequel.asc(:created_at)
        end
      end

      it "should raise an error if a 'first' or 'last' argument is not passed" do
        artist_id = id_for(artist)

        assert_invalid_query \
          "Tried to access the connection 'albums' without a 'first' or 'last' argument.",
          <<-GRAPHQL
            query Query {
              node(id: "#{artist_id}") {
                id,
                ... on Artist {
                  first_name,
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
                  [true, false].each do |paginating_through_interface|
                    desc = "paginating #{paginating_forward ? 'forward' : 'backward'} through a #{paginating_through_interface ? 'interface' : 'type'} requesting #{all_records_requested ? 'all' : 'some'} records #{cursor_requested ? 'and' : 'but not'} their cursors with#{'out' unless cursor_passed} a cursor to page from #{'and hasNextPage' if has_next_page_passed} #{'and hasPreviousPage' if has_previous_page_passed}"

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

                    it "on a one-to-many association should support #{desc}" do
                      all_albums      = paginating_through_interface ? releases : albums
                      expected_albums = all_albums
                      expected_albums = expected_albums.reverse unless paginating_forward

                      args = {}
                      args[paginating_forward ? :first : :last  ] = all_records_requested ? all_albums.length : 3
                      args[paginating_forward ? :after : :before] = to_cursor(expected_albums[1].created_at) if cursor_passed

                      expected_albums = expected_albums[2..-1] if cursor_passed
                      expected_albums = expected_albums[0..2] unless all_records_requested
                      expected_albums = expected_albums.reverse unless paginating_forward

                      artist_id = id_for(artist)

                      graphql =
                        <<-GRAPHQL
                          query Query {
                            node(id: "#{artist_id}") {
                              id,
                              ... on Artist {
                                first_name,
                                #{paginating_through_interface ? 'releases' : 'albums'}(#{graphql_args(args)}) {
                                  count
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
                        'count' => all_albums.length,
                        'edges' => expected_albums.map { |a|
                          h = {'node' => {'id' => id_for(a), 'name' => a.name}}
                          h['cursor'] = to_cursor(a.created_at) if cursor_requested
                          h
                        }
                      }

                      expectation['pageInfo'] = page_info if page_info

                      assert_result \
                        'data' => {
                          'node' => {
                            'id' => id_for(artist),
                            'first_name' => artist.first_name,
                            (paginating_through_interface ? 'releases' : 'albums') => expectation,
                          }
                        }
                    end

                    it "on a top-level connection query should support #{desc}" do
                      # TODO: Hacky, clean up.
                      Track.dataset.delete
                      Publisher.dataset.delete
                      Album.exclude(artist_id: artist.id).delete
                      Compilation.exclude(artist_id: artist.id).delete

                      all_albums      = paginating_through_interface ? releases : albums
                      expected_albums = all_albums
                      expected_albums = expected_albums.reverse unless paginating_forward

                      args = {}
                      args[paginating_forward ? :first : :last  ] = all_records_requested ? all_albums.length : 3
                      args[paginating_forward ? :after : :before] = to_cursor(expected_albums[1].created_at) if cursor_passed

                      expected_albums = expected_albums[2..-1] if cursor_passed
                      expected_albums = expected_albums[0..2] unless all_records_requested
                      expected_albums = expected_albums.reverse unless paginating_forward

                      graphql =
                        <<-GRAPHQL
                          query Query {
                            connections {
                              #{paginating_through_interface ? 'releases' : 'albums'}(#{graphql_args(args)}) {
                                # count
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
                        GRAPHQL

                      execute_query(graphql)

                      expectation = {
                        # 'count' => all_albums.length,
                        'edges' => expected_albums.map { |a|
                          h = {'node' => {'id' => id_for(a), 'name' => a.name}}
                          h['cursor'] = to_cursor(a.created_at) if cursor_requested
                          h
                        }
                      }

                      expectation['pageInfo'] = page_info if page_info

                      assert_result \
                        'data' => {
                          'connections' => {
                            (paginating_through_interface ? 'releases' : 'albums') => expectation,
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
    end

    describe "against an interface" do
      it "should raise an error if a 'first' or 'last' argument is not passed"
      it "should support all the same permutations"
    end
  end

  describe "on a top-level connection" do
    describe "on a type" do
      it "should raise an error if a 'first' or 'last' argument is not passed"
      it "should support all the same permutations"
    end

    describe "on an interface" do
      it "should raise an error if a 'first' or 'last' argument is not passed"
      it "should support all the same permutations"
    end
  end
end
