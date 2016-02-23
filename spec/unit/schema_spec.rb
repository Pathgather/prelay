# frozen_string_literal: true

require 'spec_helper'

class SchemaSpec < PrelaySpec
  describe "#initialize" do
    it "should append the schema to the internal list of schemas" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS

        s = Prelay::Schema.new
        assert_equal [SCHEMA, s], Prelay::SCHEMAS

        Prelay::SCHEMAS.pop
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end

    it "with a :temporary option should not append the schema to the internal list of schemas" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS

        s = Prelay::Schema.new(temporary: true)

        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end
  end

  describe "#freeze" do
    it "should deep-freeze the contents of the schema"
  end

  describe "#to_graphql_schema" do
    it "should give the query and mutation collections a prefix, which defaults to 'Client'"
  end
end
