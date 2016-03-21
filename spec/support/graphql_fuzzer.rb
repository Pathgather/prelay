# frozen_string_literal: true

class GraphQLFuzzer
  RECURSIVE_MERGE_PROC = proc { |k,o,n|
    if o.is_a?(Hash) && n.is_a?(Hash)
      o.merge(n, &RECURSIVE_MERGE_PROC)
    else
      true
    end
  }

  def initialize(type:)
    @type = type
  end

  def fuzz
    fragments  = []
    types_hash = {}

    all_types =
      if @type < Prelay::Type
        [@type] + @type.interfaces.keys
      elsif @type < Prelay::Interface
        @type.types
      else
        raise "Unsupported type: #{@type.inspect}"
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
      if @type < Prelay::Type
        types_hash.delete(@type)
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
          subgraphql, substructure, subfragments = GraphQLFuzzer.new(type: value).fuzz
          fragments += subfragments

          structure[this_type][field] ||= {}
          structure[this_type][field].merge!(substructure){|k,o,n| o.merge(n, &RECURSIVE_MERGE_PROC)}

          field_text << %{\n#{field} { #{subgraphql} } }
        end
      end

      if rand > 0.8
        # Shove it in a fragment!
        fragment_name = random_fragment_name
        t = this_type == :default ? @type : this_type
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
      fields = fields.merge(fieldset, &RECURSIVE_MERGE_PROC)
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

  def type_for(object)
    schema.type_for_model!(object.class)
  end

  def type_name_for(object)
    type_for(object).graphql_object.to_s
  end

  def id_for(object)
    encode_prelay_id type: type_name_for(object), pk: object.pk
  end

  def encode_prelay_id(type:, pk:)
    Base64.strict_encode64 "#{type}:#{pk}"
  end

  def random_fragment_name
    SecureRandom.base64.gsub(/[0-9+\/=]/, '')
  end

  def schema
    @type.schema
  end
end
