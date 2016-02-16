# frozen_string_literal: true

require 'spec_helper'

class DatasetScopeSpec < PrelaySpec
  let(:track) { Track.where(:high_quality).first }

  it "should support dataset scopes on types" do
    id = encode_prelay_id(type: 'BestTrack', pk: track.pk)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on BestTrack {
            name
          }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => track.name
        }
      }

    assert_sqls [
      %(SELECT random() AS "rand", "tracks"."id", "tracks"."name" FROM "tracks" WHERE (("tracks"."id" = '#{track.id}') AND "high_quality")),
    ]
  end
end
