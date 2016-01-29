# frozen_string_literal: true

require 'spec_helper'

class TypeGraphQLObjectSpec < PrelaySpec
  describe "for a type" do
    let(:object) { AlbumType.graphql_object }

    it "should translate it to a GraphQL object" do
      assert_instance_of GraphQL::ObjectType, object
      assert_equal 'Album', object.name
      assert_equal ['id', 'name', 'upvotes', 'high_quality', 'popularity', 'artist', 'tracks', 'publisher', 'first_track', 'first_five_tracks'], object.fields.keys
      assert_equal "An album released by a musician", object.description
    end

    it "should translate its attributes to GraphQL fields" do
      field = object.fields['name']

      assert_instance_of GraphQL::Field, field
      assert_equal 'name', field.name
      assert_equal 'String!', field.type.to_s
      assert_equal "The name of the album", field.description
    end

    it "should translate its many_to_one associations to GraphQL fields" do
      field = object.fields['artist']

      assert_instance_of GraphQL::Field, field
      assert_equal 'artist', field.name
      assert_equal 'Artist!', field.type.to_s
      assert_equal "The artist who released the album.", field.description
    end

    it "should translate its one_to_many associations to GraphQL connections" do
      field = object.fields['tracks']

      assert_instance_of GraphQL::Field, field
      assert_equal 'tracks', field.name
      assert_equal 'TrackConnection', field.type.to_s
      assert_equal "The tracks on this album.", field.description
    end

    it "should translate its one_to_one associations to GraphQL fields" do
      field = object.fields['publisher']

      assert_instance_of GraphQL::Field, field
      assert_equal 'publisher', field.name
      assert_equal 'Publisher', field.type.to_s
      assert_equal "The publisher responsible for releasing the album.", field.description
    end
  end
end
