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

    it "should raise an error if a schema hasn't been declared yet" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(Prelay::DefinitionError){class MutationTest < Prelay::Mutation; end}

        Prelay::SCHEMAS.replace([SCHEMA])

        assert_equal "Tried to subclass Prelay::Mutation (MutationSpec::MutationTest) without first instantiating a Prelay::Schema for it to belong to!", error.message
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

  describe "when introspected" do
    mock_schema do
      type :Album

      mutation :UpdateAlbum do
        type :Album
        description "A mutation to update an album"
      end
    end

    it "should be correct" do
      m = schema.graphql_schema.mutation.fields['update_album']
      assert_equal "update_album", m.name
      skip "Not sure how to get this information from the GraphQL gem"
      assert_equal "A mutation to update an album", m.description
      assert_nil m.deprecation_reason
      # Probably other stuff we should check?
    end
  end

  describe "when declared" do
    it "should accept the actual type object as well as a name"
  end
end
