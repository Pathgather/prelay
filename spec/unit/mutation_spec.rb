# frozen_string_literal: true

require 'spec_helper'

class MutationSpec < PrelaySpec
  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        m = Class.new(Prelay::Mutation)
        assert_equal SCHEMA, m.schema
        assert SCHEMA.mutations.include?(m)
        SCHEMA.mutations.delete(m)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_mutations = SCHEMA.mutations

        s = Prelay::Schema.new(temporary: true)
        m = Class.new(Prelay::Mutation(schema: s))
        assert_equal s, m.schema
        assert_equal [m], s.mutations

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_mutations, SCHEMA.mutations
      end
    end
  end
end
