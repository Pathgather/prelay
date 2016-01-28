# frozen_string_literal: true

require 'spec_helper'

class GraphQLObjectSpec < PrelaySpec
  it "should translate a type to a GraphQL object" do
    object = AlbumType.graphql_object

    assert_instance_of GraphQL::ObjectType, object
    assert_equal 'Album', object.name
    assert_equal ['id', 'name', 'upvotes', 'high_quality', 'popularity', 'artist', 'tracks', 'publisher'], object.fields.keys
    assert_equal "An album released by a musician", object.description
  end

  it "should translate a type's attributes to GraphQL fields" do
    object = AlbumType.graphql_object
    field  = object.fields['name']

    assert_instance_of GraphQL::Field, field
    assert_equal 'name', field.name
    assert_equal 'String', field.type.to_s
  end

  it "should translate a type's many_to_one associations to GraphQL fields" do
    object = AlbumType.graphql_object
    field  = object.fields['artist']

    assert_instance_of GraphQL::Field, field
    assert_equal 'artist', field.name
    assert_equal 'Artist', field.type.to_s
  end

  it "should translate a type's one_to_many associations to GraphQL connections" do
    object = AlbumType.graphql_object
    field  = object.fields['tracks']

    assert_instance_of GraphQL::Field, field
    assert_equal 'tracks', field.name
    assert_equal 'TrackConnection', field.type.to_s
  end

  it "should translate a type's one_to_one associations to GraphQL fields" do
    object = AlbumType.graphql_object
    field  = object.fields['publisher']

    assert_instance_of GraphQL::Field, field
    assert_equal 'publisher', field.name
    assert_equal 'Publisher', field.type.to_s
  end
end
