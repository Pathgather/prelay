# frozen_string_literal: true

require 'spec_helper'

class PrelayModuleSpec < PrelaySpec
  describe ".primary_schema" do
    it "should return the permanent schema that was declared first" do
      assert_equal SCHEMA, Prelay.primary_schema
    end

    it "should yield to the block when a schema is not found" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(RuntimeError) { Prelay.primary_schema { raise "Custom Error!" } }
        assert_equal "Custom Error!", error.message

        Prelay::SCHEMAS << SCHEMA
      end
    end

    it "should raise an error if a schema is not found and no block is provided" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(Prelay::Error) { Prelay.primary_schema }
        assert_equal "Tried to access the primary Prelay schema when none has been defined.", error.message

        Prelay::SCHEMAS << SCHEMA
      end
    end
  end
end
