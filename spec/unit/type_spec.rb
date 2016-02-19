# frozen_string_literal: true

require 'spec_helper'

class TypeSpec < PrelaySpec
  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        t = Class.new(Prelay::Type)
        assert_equal SCHEMA, t.schema
        assert SCHEMA.types.include?(t)
        SCHEMA.types.delete(t)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_types = SCHEMA.types

        s = Prelay::Schema.new(temporary: true)
        t = Class.new(Prelay::Type(schema: s))
        assert_equal s, t.schema
        assert_equal [t], s.types

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_types, SCHEMA.types
      end
    end
  end
end
