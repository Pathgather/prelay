# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class DependentColumnsQuerySpec < PrelaySpec
  let(:artist) { Artist.first }

  describe "when the dependent_columns are just columns" do
    mock_schema do
      ArtistType.class_eval do
        string :name, dependent_columns: [:first_name, :last_name]

        def name
          record.first_name + ' ' + record.last_name
        end
      end
    end

    it "should handle a field that is dependent on multiple columns" do
      id = id_for(artist)

      execute_query <<-GRAPHQL
        query Query {
          node(id: "#{id}") {
            id,
            ... on Artist { name, upvotes }
          }
        }
      GRAPHQL

      assert_result \
        'data' => {
          'node' => {
            'id' => id,
            'name' => artist.first_name + ' ' + artist.last_name,
            'upvotes' => artist.upvotes,
          }
        }

      assert_sqls [
        %(SELECT "artists"."id", "artists"."upvotes", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))
      ]
    end

    it "should not try to load the same column twice, even when the dependencies are duplicative" do
      id = id_for(artist)

      execute_query "query Query { node(id: \"#{id}\") { id, ... on Artist { first_name, name, upvotes } } }"
      assert_result 'data' => { 'node' => { 'id' => id, 'first_name' => artist.first_name, 'name' => artist.first_name + ' ' + artist.last_name, 'upvotes' => artist.upvotes } }
      assert_sqls [%(SELECT "artists"."id", "artists"."first_name", "artists"."upvotes", "artists"."last_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))]

      execute_query "query Query { node(id: \"#{id}\") { id, ... on Artist { name, first_name, upvotes } } }"
      assert_result 'data' => { 'node' => { 'id' => id, 'first_name' => artist.first_name, 'name' => artist.first_name + ' ' + artist.last_name, 'upvotes' => artist.upvotes } }
      assert_sqls [%(SELECT "artists"."id", "artists"."first_name", "artists"."upvotes", "artists"."last_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))]
    end
  end

  describe "when the dependent_columns are arbitrary SQL expressions" do
    mock_schema do
      ArtistType.class_eval do
        integer :double_upvotes, dependent_columns: (Sequel.expr(:upvotes) * 2).as(:double_upvotes)

        def double_upvotes
          record[:double_upvotes]
        end
      end
    end

    it "should run those expressions" do
      id = id_for(artist)

      execute_query <<-GRAPHQL
        query Query {
          node(id: "#{id}") {
            id,
            ... on Artist { upvotes, double_upvotes }
          }
        }
      GRAPHQL

      assert_result \
        'data' => {
          'node' => {
            'id' => id,
            'upvotes' => artist.upvotes,
            'double_upvotes' => artist.upvotes * 2,
          }
        }

      assert_sqls [
        %(SELECT "artists"."id", "artists"."upvotes", ("upvotes" * 2) AS "double_upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))
      ]
    end

    it "should handle those expressions being duplicated" do
      id = id_for(artist)

      execute_query <<-GRAPHQL
        query Query {
          node(id: "#{id}") {
            id,
            ... on Artist { upvotes, double_upvotes, double_upvotes }
          }
        }
      GRAPHQL

      assert_result \
        'data' => {
          'node' => {
            'id' => id,
            'upvotes' => artist.upvotes,
            'double_upvotes' => artist.upvotes * 2,
          }
        }

      assert_sqls [
        %(SELECT "artists"."id", "artists"."upvotes", ("upvotes" * 2) AS "double_upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))
      ]
    end
  end
end
