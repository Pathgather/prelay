# frozen_string_literal: true

require 'spec_helper'

class QuerySpec < PrelaySpec
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
end
