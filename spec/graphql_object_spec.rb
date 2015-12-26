require 'spec_helper'

class GraphQLObjectSpec < PrelaySpec
  it "should translate a model to a GraphQL object" do
    object = PrelaySpec::Album.graphql_object

    assert_instance_of GraphQL::ObjectType, object
    assert_equal 'Album', object.name
    assert_equal ['id', 'name', 'artist', 'tracks'], object.fields.keys
    assert_equal "An album released by a musician", object.description
  end

  it "should translate a model's attributes to GraphQL fields" do
    object = PrelaySpec::Album.graphql_object
    field  = object.fields['name']

    assert_instance_of GraphQL::Field, field
    assert_equal 'name', field.name
    assert_equal 'String', field.type.to_s
  end

  it "should translate a model's many_to_one associations to GraphQL fields" do
    object = PrelaySpec::Album.graphql_object
    field  = object.fields['artist']

    assert_instance_of GraphQL::Field, field
    assert_equal 'artist', field.name
    assert_equal 'Artist', field.type.to_s
  end

  it "should translate a model's one_to_many associations to GraphQL connections" do
    object = PrelaySpec::Album.graphql_object
    field  = object.fields['tracks']

    assert_instance_of GraphQL::Field, field
    assert_equal 'tracks', field.name
    assert_equal 'TrackConnection', field.type.to_s
  end
end
