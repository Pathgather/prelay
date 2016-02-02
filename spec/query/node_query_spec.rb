# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class NodeQuerySpec < PrelaySpec
  let(:album) { Album.first }

  it "should support refetching an item by its relay id" do
    id = encode 'Album', album.id

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
    id = encode 'Album', album.id

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
    id = encode 'Album', album.id

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
    id = encode('Album', uuid)

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
    id = encode('NonexistentObjectClass', SecureRandom.uuid)
    assert_invalid_query "Not a valid object type: NonexistentObjectClass", "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_sqls []
  end

  it "should return an error when given an empty id" do
    assert_invalid_query "Not a valid object id: \"\"", "query Query { node(id: \"\") { id ... on Album { name } } }"
    assert_sqls []
  end
end
