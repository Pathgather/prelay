# frozen_string_literal: true

require 'spec_helper'

class InterfaceSpec < PrelaySpec
  describe "when inherited from" do
    it "should have the first schema in Prelay::SCHEMAS as its parent schema" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        i = Class.new(Prelay::Interface)
        assert_equal SCHEMA, i.schema
        assert SCHEMA.interface_set.include?(i)
        SCHEMA.interface_set.delete(i)
        assert_equal [SCHEMA], Prelay::SCHEMAS
      end
    end

    it "should raise an error if a schema hasn't been declared yet" do
      TEST_MUTEX.synchronize do
        Prelay::SCHEMAS.clear

        error = assert_raises(Prelay::DefinitionError){class InterfaceTest < Prelay::Interface; end}

        Prelay::SCHEMAS.replace([SCHEMA])

        assert_equal "Tried to subclass Prelay::Interface (InterfaceSpec::InterfaceTest) without first instantiating a Prelay::Schema for it to belong to!", error.message
      end
    end
  end

  describe "when inherited from the function that was passed a schema" do
    it "should have that schema as its parent" do
      TEST_MUTEX.synchronize do
        assert_equal [SCHEMA], Prelay::SCHEMAS
        original_interfaces = SCHEMA.interface_set

        s = Prelay::Schema.new(temporary: true)
        i = Class.new(Prelay::Interface(schema: s))
        assert_equal s, i.schema
        assert_equal [i], s.interface_set

        assert_equal [SCHEMA], Prelay::SCHEMAS
        assert_equal original_interfaces, SCHEMA.interface_set
      end
    end
  end

  describe "when introspected" do
    let :interface do
      mock :interface do
        name "Release"
        description "A collection of songs released by an artist."
        attribute :name, "The name of the release", datatype: :string
      end
    end

    let(:graphql_object) { interface.graphql_object }

    it "should translate it to a GraphQL object" do
      assert_instance_of GraphQL::InterfaceType, graphql_object
      assert_equal 'Release', graphql_object.name
      assert_equal ['id', 'name'], graphql_object.fields.keys
      assert_equal "A collection of songs released by an artist.", graphql_object.description
    end

    it "should translate its attributes to GraphQL fields" do
      field = graphql_object.fields['name']

      assert_instance_of GraphQL::Field, field
      assert_equal 'name', field.name
      assert_equal 'String!', field.type.to_s
      assert_equal "The name of the release", field.description
    end

    it "should translate its many_to_one associations to GraphQL fields" do
      skip
      field = graphql_object.fields['artist']

      assert_instance_of GraphQL::Field, field
      assert_equal 'artist', field.name
      assert_equal 'Artist!', field.type.to_s
      assert_equal "The artist who released the release.", field.description
    end

    it "should translate its one_to_many associations to GraphQL connections" do
      skip
      field = graphql_object.fields['tracks']

      assert_instance_of GraphQL::Field, field
      assert_equal 'tracks', field.name
      assert_equal 'TrackConnection', field.type.to_s
      assert_equal "The tracks on this release.", field.description
    end

    it "should translate its one_to_one associations to GraphQL fields" do
      skip
      field = graphql_object.fields['publisher']

      assert_instance_of GraphQL::Field, field
      assert_equal 'publisher', field.name
      assert_equal 'Publisher', field.type.to_s
      assert_equal "The publisher responsible for releasing the release.", field.description
    end
  end
end
