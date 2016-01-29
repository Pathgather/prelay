# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class DependentColumnsQuerySpec < PrelaySpec
  let(:artist) { Artist.first }

  it "should handle a field that is dependent on multiple columns" do
    id = encode 'Artist', artist.id

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Artist { name, popularity }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => artist.first_name + ' ' + artist.last_name,
          'popularity' => artist.popularity,
        }
      }

    assert_sqls [
      %(SELECT "artists"."id", "artists"."first_name", "artists"."last_name", "artists"."popularity" FROM "artists" WHERE ("artists"."id" = '#{artist.id}') ORDER BY "artists"."id")
    ]
  end
end
