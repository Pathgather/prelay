require 'spec_helper'

class GraphQLObjectSpec < PrelaySpec
  it "should translate a model to a GraphQL object" do
    object = PrelaySpec::Artist.graphql_object

    assert_instance_of GraphQL::ObjectType, object
    assert_equal "Artist", object.name
    assert_equal ["name"], object.fields.keys.sort
    assert_equal "A musician with at least one released album", object.description
  end

  it "should translate a model's attributes to GraphQL objects" do
    object = PrelaySpec::Artist.graphql_object
    field  = object.fields['name']

    assert_instance_of GraphQL::Field, field
    assert_equal 'name', field.name
    assert_equal 'String', field.type.to_s
  end
end
