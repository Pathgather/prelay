# frozen_string_literal: true

require 'spec_helper'

class QuerySpec < PrelaySpec
  mock_schema do
    query :Albums do
      type AlbumType
      description "A query to return all albums in the DB"
    end
  end

  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        q = Class.new(Prelay::Query)
        assert_equal SCHEMA, q.schema
        assert SCHEMA.queries.include?(q)
        SCHEMA.queries.delete(q)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end

    it "should raise an error if a schema hasn't been declared yet" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(Prelay::DefinitionError){class QueryTest < Prelay::Query; end}

        Prelay::SCHEMAS.replace([SCHEMA])

        assert_equal "Tried to subclass Prelay::Query (QuerySpec::QueryTest) without first instantiating a Prelay::Schema for it to belong to!", error.message
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_queries = SCHEMA.queries

        s = Prelay::Schema.new(temporary: true)
        q = Class.new(Prelay::Query(schema: s))
        assert_equal s, q.schema
        assert_equal [q], s.queries

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_queries, SCHEMA.queries
      end
    end
  end

  describe "when introspected" do
    it "should be correct" do
      q = schema.graphql_schema.query.fields['albums']
      assert_equal "albums", q.name
      assert_equal "A query to return all albums in the DB", q.description
      assert_nil q.deprecation_reason
      assert_equal({}, q.arguments)
      assert_equal(schema.graphql_schema.types['Album'], q.type)
    end
  end
end
