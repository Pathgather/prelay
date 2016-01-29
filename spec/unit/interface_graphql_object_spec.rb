# frozen_string_literal: true

require 'spec_helper'

class InterfaceGraphQLObjectSpec < PrelaySpec
  describe "for an interface" do
    let(:object) { ReleaseInterface.graphql_object }

    it "should translate it to a GraphQL object" do
      assert_instance_of GraphQL::InterfaceType, object
      assert_equal 'Release', object.name
      assert_equal ['id', 'name', 'upvotes', 'high_quality', 'popularity', 'artist', 'tracks', 'publisher'], object.fields.keys
      assert_equal "A collection of songs released by an artist.", object.description
    end

    it "should translate its attributes to GraphQL fields" do
      field = object.fields['name']

      assert_instance_of GraphQL::Field, field
      assert_equal 'name', field.name
      assert_equal 'String!', field.type.to_s
      assert_equal "The name of the release", field.description
    end

    it "should translate its many_to_one associations to GraphQL fields" do
      field = object.fields['artist']

      assert_instance_of GraphQL::Field, field
      assert_equal 'artist', field.name
      assert_equal 'Artist!', field.type.to_s
      assert_equal "The artist who released the release.", field.description
    end

    it "should translate its one_to_many associations to GraphQL connections" do
      field = object.fields['tracks']

      assert_instance_of GraphQL::Field, field
      assert_equal 'tracks', field.name
      assert_equal 'TrackConnection', field.type.to_s
      assert_equal "The tracks on this release.", field.description
    end

    it "should translate its one_to_one associations to GraphQL fields" do
      field = object.fields['publisher']

      assert_instance_of GraphQL::Field, field
      assert_equal 'publisher', field.name
      assert_equal 'Publisher', field.type.to_s
      assert_equal "The publisher responsible for releasing the release.", field.description
    end
  end
end
