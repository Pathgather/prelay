# frozen_string_literal: true

require 'securerandom'
require 'spec_helper'

class NodeQuerySpec < PrelaySpec
  let(:album) { Album.first }

  it "should support refetching an item by its relay id" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          'name' => album.name
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}'))
    ]
  end

  it "should support retrieving fields on objects via interfaces" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          __typename,
          ... on Release { popularity }
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          '__typename' => 'Album',
          'popularity' => album.popularity,
          'name'       => album.name,
        }
      }
  end

  it "should return record typenames when requested" do
    id = id_for(album)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id,
          __typename,
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => {
          'id' => id,
          '__typename' => 'Album',
          'name' => album.name
        }
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{album.id}'))
    ]
  end

  it "should return nil when a record by a given id doesn't exist" do
    uuid = SecureRandom.uuid
    id = encode_prelay_id(type: 'Album', pk: uuid)

    execute_query <<-GRAPHQL
      query Query {
        node(id: "#{id}") {
          id
          ... on Album { name }
        }
      }
    GRAPHQL

    assert_result \
      'data' => {
        'node' => nil
      }

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("albums"."id" = '#{uuid}'))
    ]
  end

  it "should return an error when given a gibberish id" do
    id = "RG9uJ3QgbG9vayBhdCB0aGlzISBJdCdzIGp1c3QgZ2liYmVyaXNoIQ=="
    assert_invalid_query "Not a valid object id: \"#{id}\"", "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_sqls []
  end

  it "should return an error when given an id that refers to a nonexistent object type" do
    id = encode_prelay_id(type: 'NonexistentObjectClass', pk: SecureRandom.uuid)
    assert_invalid_query "Not a valid object type: NonexistentObjectClass", "query Query { node(id: \"#{id}\") { id ... on Album { name } } }"
    assert_sqls []
  end

  it "should return an error when given an empty id" do
    assert_invalid_query "Not a valid object id: \"\"", "query Query { node(id: \"\") { id ... on Album { name } } }"
    assert_sqls []
  end

  def recursive_merge_proc
    recursive_merge = proc { |k,o,n|
      if o.is_a?(Hash) && n.is_a?(Hash)
        o.merge(n, &recursive_merge)
      else
        true
      end
    }
  end

  def fuzz(type, fragments: [])
    types_hash = {}

    all_types =
      if type < Prelay::Type
        [type] + type.interfaces.keys
      elsif type < Prelay::Interface
        type.types
      else
        raise "Unsupported type: #{type.inspect}"
      end

    all_types.each do |t|
      fields = t.attributes.keys.each_with_object({}){|key, hash| hash[key] = true}

      t.associations.each do |key, association|
        next if association.association_type == :one_to_many
        fields[key] = association.target_type
      end

      fields[:id] = true
      fields[:__typename] = true

      types_hash[t] = fields
    end

    types_hash[:default] =
      if type < Prelay::Type
        types_hash.delete(type)
      else
        {id: true, __typename: true}
      end

    graphql = String.new
    structure = {}

    (rand(types_hash.length) + 1).times do
      graphql << "\n"
      this_type, fields = types_hash.to_a.sample
      structure[this_type] ||= {}

      field_text = String.new

      fields.to_a.sample(rand(fields.length) + 1).each do |field, value|
        if value == true
          structure[this_type][field] = true
          field_text << " #{field}, "
        else
          subgraphql, substructure = fuzz(value, fragments: fragments)

          structure[this_type][field] ||= {}
          structure[this_type][field].merge!(substructure){|k,o,n| o.merge(n, &recursive_merge_proc)}

          field_text << %{\n#{field} { #{subgraphql} } }
        end
      end

      if rand > 0.8
        # Shove it in a fragment!
        fragment_name = "f#{fragments.length}"
        t = this_type == :default ? type : this_type
        fragments << %{\n fragment #{fragment_name} on #{t.graphql_object} { #{field_text} } }
        graphql << %{ ...#{fragment_name} }
      else
        if this_type == :default
          graphql << field_text
        else
          graphql << %{\n... on #{this_type.graphql_object} { #{field_text} } }
        end
      end
    end

    [graphql, structure, fragments]
  end

  def object_implements_type?(object, type)
    if type < Prelay::Type
      object.is_a?(type.model)
    elsif type < Prelay::Interface
      type.types.any?{|t| object.is_a?(t.model)}
    else
      raise "Unsupported! #{type.inspect}"
    end
  end

  def build_expected_json(object:, structure:)
    fields = {}

    structure.each do |type, fieldset|
      next unless type == :default || object_implements_type?(object, type)
      fields = fields.merge(fieldset, &recursive_merge_proc)
    end

    fields.each_with_object({}) do |(field, value), hash|
      hash[field.to_s] =
        case field
        when :__typename
          type_name_for(object)
        when :id
          id_for(object)
        else
          if value == true
            object.send(field)
          elsif subobject = object.send(field)
            build_expected_json(object: subobject, structure: value)
          else
            nil
          end
        end
    end
  end

  100.times do
    it "should support fragments, however they appear" do
      graphql, structure, fragments = fuzz(AlbumType)

      s = <<-SQL
        query Query { node(id: "#{id_for(album)}") { id, __typename, ... on Album { #{graphql} } } }
        #{fragments.join("\n")}
      SQL

      execute_query(s)

      assert_result \
        'data' => {
          'node' => build_expected_json(object: album, structure: structure).merge('id' => id_for(album), '__typename' => "Album")
        }
    end
  end
end
