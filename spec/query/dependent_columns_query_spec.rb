# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class DependentColumnsQuerySpec < PrelaySpec
  let(:artist) { Artist.first }

  it "should support refetching an item by its relay id" do
    id = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => artist.first_name + ' ' + artist.last_name,
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id")
    ]
  end
end
