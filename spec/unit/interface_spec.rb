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

  describe "when introspected" do
    let(:graphql_object) { schema.find_type("Release").graphql_object }

    it "should translate it to a GraphQL object" do
      assert_instance_of GraphQL::InterfaceType, graphql_object
      assert_equal 'Release', graphql_object.name
      assert_equal ['id', 'name', 'upvotes', 'high_quality', 'popularity', 'artist', 'tracks', 'publisher'], graphql_object.fields.keys
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
      field = graphql_object.fields['artist']

      assert_instance_of GraphQL::Field, field
      assert_equal 'artist', field.name
      assert_equal 'Artist!', field.type.to_s
      assert_equal "The artist who released the release.", field.description
    end

    it "should translate its one_to_many associations to GraphQL connections" do
      field = graphql_object.fields['tracks']

      assert_instance_of GraphQL::Field, field
      assert_equal 'tracks', field.name
      assert_equal 'TrackConnection', field.type.to_s
      assert_equal "The tracks on this release.", field.description
    end

    it "should translate its one_to_one associations to GraphQL fields" do
      field = graphql_object.fields['publisher']

      assert_instance_of GraphQL::Field, field
      assert_equal 'publisher', field.name
      assert_equal 'Publisher', field.type.to_s
      assert_equal "The publisher responsible for releasing the release.", field.description
    end
  end

  describe "when implemented by a type" do
    it "should receive the attributes and associations of the interface" do
      s = Prelay::Schema.new(temporary: true)

      a = Class.new(Prelay::Type(schema: s)) do
        name "AssociationTargetType"
        string :column_1, "My Column #1", nullable: false
      end

      i = Class.new(Prelay::Interface(schema: s)) do
        name "ImplementedInterface"
        string :column_1, "Column #1", nullable: false
        string :column_2, "Column #2", nullable: false

        one_to_many :associated_things, target: a, local_column: :test_local_column, remote_column: :test_remote_column
      end

      t = Class.new(Prelay::Type(schema: s)) do
        name "InterfaceInheritingType"
        interface i
        string :column_1, "My Column #1", nullable: false
      end

      assert_equal [:column_1, :column_2], t.attributes.keys
      assert_equal [:associated_things], t.associations.keys
    end

    describe "attributes" do
      it "when the type is missing an attribute should raise an error" do
        s = Prelay::Schema.new(temporary: true)
        i = Class.new(Prelay::Interface(schema: s)) do
          name "UnimplementedInterface"
          string :column_1, "Column #1", nullable: false
          string :column_2, "Column #2", nullable: false
        end

        t = Class.new(Prelay::Type(schema: s)) do
          name "BadType"
          interface i
        end

        t.attributes.delete(:column_2)

        error = assert_raises(Prelay::Error) { s.graphql_schema }
        assert_equal "BadType claims to implement UnimplementedInterface but doesn't have a column_2 attribute", error.message
      end

      it "when the type's attribute is the wrong datatype should raise an error" do
        s = Prelay::Schema.new(temporary: true)
        i = Class.new(Prelay::Interface(schema: s)) do
          name "UnimplementedInterface"
          string :column_1, "Column #1", nullable: false
        end

        t = Class.new(Prelay::Type(schema: s)) do
          name "BadType"
          interface i
          integer :column_1, "My Column #1", nullable: false
        end

        error = assert_raises(Prelay::Error) { s.graphql_schema }
        assert_equal "BadType claims to implement UnimplementedInterface but column_1 has the wrong datatype", error.message
      end

      it "when the type's attribute has different nullability should raise an error" do
        s = Prelay::Schema.new(temporary: true)
        i = Class.new(Prelay::Interface(schema: s)) do
          name "UnimplementedInterface"
          string :column_1, "Column #1", nullable: false
        end

        t = Class.new(Prelay::Type(schema: s)) do
          name "BadType"
          interface i
          string :column_1, "My Column #1", nullable: true
        end

        error = assert_raises(Prelay::Error) { s.graphql_schema }
        assert_equal "BadType claims to implement UnimplementedInterface but column_1 has the wrong nullability", error.message
      end
    end

    describe "associations" do
      it "when the type is missing an association should raise an error" do
        s = Prelay::Schema.new(temporary: true)

        a = Class.new(Prelay::Type(schema: s)) do
          name "AssociatedType"
        end

        i = Class.new(Prelay::Interface(schema: s)) do
          name "UnimplementedInterface"

          one_to_many :things, target: a, remote_column: :thing_id
        end

        t = Class.new(Prelay::Type(schema: s)) do
          name "BadType"
          interface i
        end

        t.associations.delete(:things)

        error = assert_raises(Prelay::Error) { s.graphql_schema }
        assert_equal "BadType claims to implement UnimplementedInterface but doesn't have a things association", error.message
      end

      it "when the type has a wrong association should raise an error" do
        s = Prelay::Schema.new(temporary: true)

        a = Class.new(Prelay::Type(schema: s)) do
          name "AssociatedType"
        end

        i = Class.new(Prelay::Interface(schema: s)) do
          name "UnimplementedInterface"

          one_to_many :things, target: a, remote_column: :thing_id
        end

        t = Class.new(Prelay::Type(schema: s)) do
          name "BadType"
          interface i

          many_to_one :things, target: a, nullable: false, local_column: :thing_id
        end

        error = assert_raises(Prelay::Error) { s.graphql_schema }
        assert_equal "BadType claims to implement UnimplementedInterface but its things association has a different type (many_to_one instead of one_to_many)", error.message
      end
    end
  end
end
