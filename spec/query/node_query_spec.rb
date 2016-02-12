# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class NodeQuerySpec < PrelaySpec
  let(:album) { Album.first }

  it "should support refetching an item by its relay id" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => album.name
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}'))
    ]
  end

  it "should support retrieving fields on objects via interfaces" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          __typename,
          ... on Release { popularity }
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          '__typename' => 'Album',
          'popularity' => album.popularity,
          'name'       => album.name,
        }
      }
  end

  it "should return record typenames when requested" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          __typename,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          '__typename' => 'Album',
          'name' => album.name
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}'))
    ]
  end

  it "should return nil when a record by a given id doesn't exist" do
    uuid = SecureRandom.uuid
    id = encode_prelay_id(type: 'Album', pk: uuid)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => nil
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{uuid}'))
    ]
  end

  it "should return an error when given a gibberish id" do
    id = "RG9uJ3QgbG9vayBhdCB0aGlzISBJdCdzIGp1c3QgZ2liYmVyaXNoIQ=="
    assert_invalid_query "Not a valid object id: \"#{id}\"", "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_sqls []
  end

  it "should return an error when given an id that refers to a nonexistent object type" do
    id = encode_prelay_id(type: 'NonexistentObjectClass', pk: SecureRandom.uuid)
    assert_invalid_query "Not a valid object type: NonexistentObjectClass", "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_sqls []
  end

  it "should return an error when given an empty id" do
    assert_invalid_query "Not a valid object id: \"\"", "query Query { node(id: \"\") { id ... on Album { name } } }"
    assert_sqls []
  end

  def fuzz(types)
    structure_by_type = {default: [:__typename]}
    graphql = '__typename,'.dup

    (rand(5) + 1).times do
      type, fields = types.to_a.sample

      chosen_fields = fields.sample(rand(fields.length) + 1)

      structure_by_type[type] ||= []
      structure_by_type[type] += chosen_fields
      structure_by_type[type].uniq!

      field_text = chosen_fields.join(', ') << ', '

      if type == :default
        graphql << field_text
      else
        graphql << <<-GRAPHQL
          ... on #{type} { #{field_text} }
        GRAPHQL
      end
    end

    [graphql, structure_by_type]
  end

  it "should support fragments, however they appear" do
    graphql, structure = fuzz \
      default: [
        :__typename,
        :id
      ],
      Album: [
        :id,
        :name,
        :upvotes,
        :high_quality,
        :popularity,
      ],
      Release: [
        :id,
        :name,
        :upvotes,
        :high_quality,
        :popularity,
      ]

    execute_query <<-SQL
      query Query { node(id: "#{id_for(album)}") { #{graphql} } }
    SQL

    fields = structure.values.flatten.uniq

    expected_json = fields.each_with_object({}) do |field, hash|
      hash[field.to_s] =
        case field
        when :__typename
          type_name_for(album)
        when :id
          id_for(album)
        else
          album.send(field)
        end
    end

    assert_result \
      'data' => {
        'node' => expected_json
      }
  end
end
