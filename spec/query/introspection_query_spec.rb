# frozen_string_literal: true

require 'spec_helper'

class IntrospectionQuerySpec < PrelaySpec
  INTROSPECTION_QUERY = <<-GRAPHQL
    query IntrospectionQuery {
      __schema {
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
        directives {
          name
          description
          args {
            ...InputValue
          }
          onOperation
          onFragment
          onField
        }
      }
    }

    fragment FullType on __Type {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        args {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        description
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }

    fragment InputValue on __InputValue {
      name
      description
      type { ...TypeRef }
      defaultValue
    }

    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
          }
        }
      }
    }
  GRAPHQL

  it "should support introspection of the schema" do
    execute_query(INTROSPECTION_QUERY)
    refute_empty @result['data']['__schema']
  end

  it "should support field introspection" do
    execute_query <<-GRAPHQL
      query introspectionQuery {
        artistType: __type(name: "Artist") { name, kind, fields { name, isDeprecated, type { name, ofType { name } } } }
      }
    GRAPHQL

    type = @result['data']['artistType']
    assert_equal 'Artist', type['name']
    assert_equal 'OBJECT', type['kind']
    assert_equal({'name' => 'id','isDeprecated' => false, 'type' => {'name' => "Non-Null", 'ofType' => {'name' => "ID"}}}, type['fields'].find{|f| f['name'] == 'id'})

    artist_fields = type['fields'].map{|f| f['name']}

    assert artist_fields.include?('name')
  end
end
