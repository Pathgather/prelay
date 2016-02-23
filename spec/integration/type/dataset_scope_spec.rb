# frozen_string_literal: true

require 'spec_helper'

class DatasetScopeSpec < PrelaySpec
  let(:track) { Track.where(:high_quality).first }

  let :type do
    mock :type do
      name "Track"
      model Track
      attribute :name, datatype: :string
      dataset_scope { |ds| ds.where(:high_quality).select{random{}.as(:rand)} }
    end
  end

  let :schema do
    type.schema
  end

  it "should support dataset scopes on types" do
    id = encode_prelay_id(type: 'Track', pk: track.pk)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Track {
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
