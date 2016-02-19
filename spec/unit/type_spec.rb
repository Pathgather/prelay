# frozen_string_literal: true

require 'spec_helper'

class TypeSpec < PrelaySpec
  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        t = Class.new(Prelay::Type)
        assert_equal SCHEMA, t.schema
        assert SCHEMA.type_set.include?(t)
        SCHEMA.type_set.delete(t)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end

    it "should raise an error if a schema hasn't been declared yet" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(Prelay::DefinitionError){class TypeTest < Prelay::Type; end}

        Prelay::SCHEMAS.replace([SCHEMA])

        assert_equal "Tried to subclass Prelay::Type (TypeSpec::TypeTest) without first instantiating a Prelay::Schema for it to belong to!", error.message
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_types = SCHEMA.type_set

        s = Prelay::Schema.new(temporary: true)
        t = Class.new(Prelay::Type(schema: s))
        assert_equal s, t.schema
        assert_equal [t], s.type_set

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_types, SCHEMA.type_set
      end
    end
  end
end
