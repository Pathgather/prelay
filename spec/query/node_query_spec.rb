require 'securerandom'
require 'spec_helper'

class NodeQuerySpec < PrelaySpec
  let(:album) { Album.first }

  it "should support refetching an item by its relay id" do
    id = encode 'Album', album.id

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_equal({'data' => {'node' => {'id' => id, 'name' => album.name}}}, result)

    assert_equal [%(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id")], sqls
  end

  it "should return record typenames when requested" do
    id = encode 'Album', album.id

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          __typename,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_equal({'data' => {'node' => {'id' => id, '__typename' => 'Album', 'name' => album.name}}}, result)

    assert_equal [%(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}') ORDER BY "albums"."id")], sqls
  end

  it "should return nil when a record by a given id doesn't exist" do
    uuid = SecureRandom.uuid
    id = encode('Album', uuid)

    result = execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_equal({'data' => {'node' => nil}}, result)

    assert_equal [%(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{uuid}') ORDER BY "albums"."id")], sqls
  end

  it "should return an error when given a gibberish id" do
    id = "RG9uJ3QgbG9vayBhdCB0aGlzISBJdCdzIGp1c3QgZ2liYmVyaXNoIQ=="
    error = execute_invalid_query "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_equal "Not a valid object id: \"#{id}\"", error.message
    assert_equal [], sqls
  end

  it "should return an error when given an id that refers to a nonexistent object type" do
    id = encode('NonexistentObjectClass', SecureRandom.uuid)
    error = execute_invalid_query "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_equal "Not a valid object type: NonexistentObjectClass", error.message
    assert_equal [], sqls
  end

  it "should return an error when given an empty id" do
    error = execute_invalid_query "query Query { node(id: \"\") { id ... on Album { name } } }"
    assert_equal "Not a valid object id: \"\"", error.message
    assert_equal [], sqls
  end
end
