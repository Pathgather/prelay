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

  describe "when introspected" do
    mock_schema do
      type :Artist
      type :Track
      type :Publisher

      type :Album do
        description "An album released by a musician"
        string :name, "The name of the album"

        many_to_one :artist, "The artist who released the album.", nullable: false
        one_to_many :tracks, "The tracks on this album."
        one_to_one  :publisher, "The publisher responsible for releasing the album.", nullable: true
      end
    end

    let(:graphql_object) { schema.find_type("Album").graphql_object }

    it "should translate it to a GraphQL object" do
      assert_instance_of GraphQL::ObjectType, graphql_object
      assert_equal 'Album', graphql_object.name
      assert_equal ['id', 'name', 'artist', 'tracks', 'publisher'], graphql_object.fields.keys
      assert_equal "An album released by a musician", graphql_object.description
    end

    it "should translate its attributes to GraphQL fields" do
      field = graphql_object.fields['name']

      assert_instance_of GraphQL::Field, field
      assert_equal 'name', field.name
      assert_equal 'String!', field.type.to_s
      assert_equal "The name of the album", field.description
    end

    it "should translate its many_to_one associations to GraphQL fields" do
      field = graphql_object.fields['artist']

      assert_instance_of GraphQL::Field, field
      assert_equal 'artist', field.name
      assert_equal 'Artist!', field.type.to_s
      assert_equal "The artist who released the album.", field.description
    end

    it "should translate its one_to_many associations to GraphQL connections" do
      field = graphql_object.fields['tracks']

      assert_instance_of GraphQL::Field, field
      assert_equal 'tracks', field.name
      assert_equal 'TrackConnection', field.type.to_s
      assert_equal "The tracks on this album.", field.description
    end

    it "should translate its one_to_one associations to GraphQL fields" do
      field = graphql_object.fields['publisher']

      assert_instance_of GraphQL::Field, field
      assert_equal 'publisher', field.name
      assert_equal 'Publisher', field.type.to_s
      assert_equal "The publisher responsible for releasing the album.", field.description
    end
  end

  describe "when an association is declared" do
    it "should demand a :nullable option, or its absence, depending on the association"

    describe "when an appropriate Sequel association exists" do
      it "should use its foreign key data"

      it "should use its association block, if any"

      it "should use its default order, if any"

      it "should accept a custom order option that may differ from the Sequel association's"

      it "should raise an error if an appropriate ordering cannot be determined"
    end

    describe "when an appropriate Sequel association does not exist" do
      it "should accept a foreign key specification"

      it "should error if a foreign key can't be unambiguously determined"
    end

    describe "when the association is to an interface" do
      it "should accept a set of types that are specifically supported"

      it "should error if an appropriate target is not given"

      it "should require a specific foreign key"
    end
  end

  describe "when an interface is given" do
    it "should raise an error if the type doesn't implement the interface exactly"
  end
end
