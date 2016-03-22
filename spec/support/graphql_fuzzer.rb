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

  def initialize(source:, entry_point: :field)
    @source = source
    @entry_point = entry_point
  end

  def structure
    @structure ||=
      case @entry_point
      when :field      then fuzzed_structure_for_field
      when :connection then fuzzed_structure_for_connection
      when :edge       then fuzzed_structure_for_edge
      else raise "Bad entry_point: #{@entry_point.inspect}"
      end
  end

  def graphql_and_fragments
    fragments = []
    graphql = String.new

    case @entry_point
    when :edge
      # TODO: Introduce random duplication.

      structure.each do |key, value|
        case key
        when :node
          subgraphql, subfragments = value.graphql_and_fragments
          graphql << "\n node { #{subgraphql} } "
          fragments += subfragments
        when :cursor
          graphql << "\n cursor "
        else
          raise "Bad key!: #{key}"
        end
      end
    when :connection
      # TODO: Introduce random duplication.

      structure.each do |key, value|
        case key
        when :edges
          subgraphql, subfragments = value.graphql_and_fragments
          graphql << "\n edges { #{subgraphql} } "
          fragments += subfragments
        when :pageInfo
          graphql << "\n pageInfo { #{value.keys.shuffle.join(', ')} } "
        else
          raise "Bad key!: #{key}"
        end
      end
    when :field
      structure.each do |this_type, fields|
        graphql << "\n"

        field_text = String.new
        fields_array = fields.to_a

        # This number is tricky. We want fields to be duplicated enough that our
        # duplicate detection is tested, but if we're not careful to keep this
        # number relatively low, query sizes can really explode, and cause specs
        # to take a loooong time. This seems to be a decent compromise.
        number_of_fields_to_duplicate = (rand(fields_array.length) * rand * rand).round

        (fields_array + fields_array.sample(number_of_fields_to_duplicate)).each do |field, value|
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
          t = this_type == :default ? @source : this_type
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
    else
      raise "Bad entry_point: #{@entry_point}"
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
    @source.schema
  end

  def fuzzed_structure_for_field
    structure = {}
    types_hash = {}

    all_types =
      if @source < Prelay::Type
        [@source] + @source.interfaces.keys
      elsif @source < Prelay::Interface
        @source.types
      else
        raise "Unsupported type: #{@source.inspect}"
      end

    all_types.each do |t|
      fields = t.attributes.keys.each_with_object({}){|key, hash| hash[key] = true}

      t.associations.each do |key, association|
        next if association.association_type == :one_to_many
        fields[key] = association
      end

      fields[:id] = true
      fields[:__typename] = true

      types_hash[t] = fields
    end

    types_hash[:default] =
      if @source < Prelay::Type
        types_hash.delete(@source)
      else
        {id: true, __typename: true}
      end

    (rand(types_hash.length) + 1).times do
      this_type, fields = types_hash.to_a.sample
      structure[this_type] ||= {}

      fields.to_a.sample(rand(fields.length) + 1).each do |field, value|
        structure[this_type][field] =
          case value
          when TrueClass
            true
          when Prelay::Type::Association
            case value.association_type
            when :one_to_one, :many_to_one
              GraphQLFuzzer.new(source: value.target_type)
            when :one_to_many
              # TODO: How to handle 'first' and 'last' arguments?
              GraphQLFuzzer.new(source: value, entry_point: :connection)
            else
              raise "Bad association type: #{value.inspect}"
            end
          else
            raise "Bad value to fuzz: #{value.inspect}"
          end
      end
    end

    structure
  end

  def fuzzed_structure_for_connection
    keys = [:edges, :hasNextPage, :hasPreviousPage]

    keys.

    structure = {edges: GraphQLFuzzer.new(source: @source, entry_point: :edge)}

    rand(2).times do
      page_info = structure[:pageInfo] ||= {}

      case i = rand(2)
      when 0 then page_info[:hasNextPage] ||= true
      when 1 then page_info[:hasPreviousPage] ||= true
      else raise "Bad value: #{i}"
      end
    end

    structure
  end

  def fuzzed_structure_for_edge
    structure = {node: GraphQLFuzzer.new(source: @source.target_type, entry_point: :field)}

    if rand < 0.5
      structure[:cursor] = true
    end

    structure
  end
end
