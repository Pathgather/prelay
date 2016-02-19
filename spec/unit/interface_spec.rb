# frozen_string_literal: true

require 'spec_helper'

class InterfaceSpec < PrelaySpec
  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        i = Class.new(Prelay::Interface)
        assert_equal SCHEMA, i.schema
        assert SCHEMA.interfaces.include?(i)
        SCHEMA.interfaces.delete(i)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_interfaces = SCHEMA.interfaces

        s = Prelay::Schema.new(temporary: true)
        i = Class.new(Prelay::Interface(schema: s))
        assert_equal s, i.schema
        assert_equal [i], s.interfaces

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_interfaces, SCHEMA.interfaces
      end
    end
  end
end
