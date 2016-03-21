# frozen_string_literal: true

class GraphQLFuzzer
  RECURSIVE_MERGE_PROC = proc { |k,o,n|
    if o.is_a?(Hash) && n.is_a?(Hash)
      o.merge(n, &RECURSIVE_MERGE_PROC)
    elsif o.is_a?(GraphQLFuzzer) && n.is_a?(GraphQLFuzzer)
      o.structure.merge!(n.structure, &RECURSIVE_MERGE_PROC)
      o
    else
      true
    end
  }

  def initialize(type:)
    @type = type
  end

  def structure
    @structure ||= build_fuzzed_structure
  end

  def graphql_and_fragments
    fragments = []
    graphql = String.new

    structure.each do |this_type, fields|
      graphql << "\n"

      field_text = String.new

      fields_array = fields.to_a
      # TODO: Fix
      #(fields_array + fields_array.sample(rand(fields.length))).each do |field, value|
      fields_array.each do |field, value|
        if value == true
          field_text << " #{field}, "
        else
          subgraphql, subfragments = value.graphql_and_fragments
          fragments += subfragments
          field_text << %{\n#{field} { #{subgraphql} } }
        end
      end

      if rand < 0.2
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

    [graphql, fragments]
  end

  def expected_json(object:)
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
            value.expected_json(object: subobject)
          else
            nil
          end
        end
    end
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

  def build_fuzzed_structure
    structure = {}
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

    (rand(types_hash.length) + 1).times do
      this_type, fields = types_hash.to_a.sample
      structure[this_type] ||= {}

      fields.to_a.sample(rand(fields.length) + 1).each do |field, value|
        structure[this_type][field] = (value == true) || GraphQLFuzzer.new(type: value)
      end
    end

    structure
  end
end
