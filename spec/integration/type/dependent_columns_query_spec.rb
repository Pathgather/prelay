# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class DependentColumnsQuerySpec < PrelaySpec
  let(:artist) { Artist.first }

  let :type do
    mock :type do
      name 'Artist'
      model Artist

      description "A musician"

      attribute :name, "The full name of the artist", datatype: :string, dependent_columns: [:first_name, :last_name]
      attribute :first_name, "The first name of the artist", datatype: :string
      attribute :upvotes, "How many upvotes the artist got", datatype: :integer

      def name
        record.first_name + ' ' + record.last_name
      end
    end
  end

  let :schema do
    type.schema
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
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))
    ]
  end

  it "should not try to load the same column twice, even when the dependencies are duplicative" do
    id = id_for(artist)

    execute_query "query Query { node(id: \"#{id}\") { id, ... on Artist { first_name, name, upvotes } } }"
    assert_result 'data' => { 'node' => { 'id' => id, 'first_name' => artist.first_name, 'name' => artist.first_name + ' ' + artist.last_name, 'upvotes' => artist.upvotes } }
    assert_sqls [%(SELECT "artists"."id", "artists"."first_name", "artists"."last_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))]

    execute_query "query Query { node(id: \"#{id}\") { id, ... on Artist { name, first_name, upvotes } } }"
    assert_result 'data' => { 'node' => { 'id' => id, 'first_name' => artist.first_name, 'name' => artist.first_name + ' ' + artist.last_name, 'upvotes' => artist.upvotes } }
    assert_sqls [%(SELECT "artists"."id", "artists"."first_name", "artists"."last_name", "artists"."upvotes" FROM "artists" WHERE ("artists"."id" = '#{artist.id}'))]
  end
end