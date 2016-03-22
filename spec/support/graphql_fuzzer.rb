# frozen_string_literal: true

class GraphQLFuzzer
  include SpecHelperMethods

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

  attr_reader :source, :entry_point

  def initialize(source:, entry_point: :field, current_depth: 0, maximum_depth: 3)
    @source        = source
    @entry_point   = entry_point
    @current_depth = current_depth
    @maximum_depth = maximum_depth
  end

  def graphql_and_fragments
    fragments = []
    graphql = String.new

    case entry_point
    when :edge
      random_superset(structure.to_a) do |key, value|
        graphql <<
          case key
          when :cursor then "\n cursor "
          when :node
            subgraphql, subfragments = value.graphql_and_fragments
            fragments += subfragments
            "\n node { #{subgraphql} } "
          else
            raise "Bad key!: #{key}"
          end
      end
    when :connection
      random_superset(structure.to_a) do |key, value|
        graphql <<
          case key
          when :hasNextPage     then "\n pageInfo { hasNextPage } "
          when :hasPreviousPage then "\n pageInfo { hasPreviousPage } "
          when :edges
            subgraphql, subfragments = value.graphql_and_fragments
            fragments += subfragments
            "\n edges { #{subgraphql} } "
          else
            raise "Bad key!: #{key}"
          end
      end
    when :field
      random_superset(structure.to_a) do |this_type, fields|
        graphql << "\n"
        field_text = String.new

        random_superset(fields.to_a) do |field, value|
          field_text <<
            if value == true
              " #{field}, "
            else
              subgraphql, subfragments = value.graphql_and_fragments
              fragments += subfragments
              args =
                if value.source.is_a?(Prelay::Type::Association) && value.source.association_type == :one_to_many
                  "(first: 5)"
                end

              "\n #{field}#{args} { #{subgraphql} } "
            end
        end

        graphql <<
          if rand < 0.2
            # Shove it in a fragment!
            fragment_name = random_fragment_name
            t = this_type == :default ? @source : this_type
            fragments << "\n fragment #{fragment_name} on #{t.graphql_object} { #{field_text} } "
            " ...#{fragment_name} "
          else
            if this_type == :default
              field_text
            else
              " ... on #{this_type.graphql_object} { #{field_text} } "
            end
          end
      end
    else
      raise "Bad entry_point: #{entry_point}"
    end

    [graphql, fragments]
  end

  def expected_json(object:)
    fields = {}

    case entry_point
    when :field
      structure.each_with_object({}) { |(type, fieldset), hash|
        next unless type == :default || object_implements_type?(object, type)
        hash.merge!(fieldset, &RECURSIVE_MERGE_PROC)
      }.each do |field, value|
        fields[field.to_s] =
          case field
          when :__typename then type_name_for(object)
          when :id         then id_for(object)
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
    when :connection
      structure.each do |key, value|
        case key
        when :hasNextPage     then (fields['pageInfo'] ||= {})['hasNextPage'] = object.length > 5
        when :hasPreviousPage then (fields['pageInfo'] ||= {})['hasPreviousPage'] = false
        when :edges           then fields['edges'] = object.first(5).map { |o| value.expected_json(object: o) }
        else raise "Bad key: #{key}"
        end
      end
    when :edge
      structure.each do |key, value|
        case key
        when :cursor then fields['cursor'] = to_cursor(object.created_at)
        when :node   then fields['node'] = value.expected_json(object: object)
        else raise "Bad key: #{key}"
        end
      end
    else
      raise "Bad entry_point: #{entry_point}"
    end

    fields
  end

  private

  def structure
    @structure ||=
      case entry_point
      when :field      then fuzzed_structure_for_field
      when :connection then fuzzed_structure_for_connection
      when :edge       then fuzzed_structure_for_edge
      else raise "Bad entry_point: #{entry_point.inspect}"
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

    random_subset(types_hash.to_a) do |this_type, fields|
      structure[this_type] = {}

      random_subset(fields.to_a) do |field, value|
        structure[this_type][field] =
          case value
          when TrueClass
            true
          when Prelay::Type::Association
            case value.association_type
            when :one_to_one, :many_to_one
              new_fuzzer(:field, value.target_type)
            when :one_to_many
              new_fuzzer(:connection, value)
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

  CONNECTION_KEYS = [:edges, :hasNextPage, :hasPreviousPage].freeze

  def fuzzed_structure_for_connection
    structure = {}

    random_subset(CONNECTION_KEYS) do |key|
      case key
      when :edges then structure[:edges] = new_fuzzer(:edge, @source)
      when :hasNextPage, :hasPreviousPage then structure[key] = true
      else raise "Bad key: #{key}"
      end
    end

    structure
  end

  EDGE_KEYS = [:node, :cursor].freeze

  def fuzzed_structure_for_edge
    structure = {}

    random_subset(EDGE_KEYS) do |key|
      case key
      when :node then structure[:node] = new_fuzzer(:field, @source.target_type)
      when :cursor then structure[:cursor] = true
      else raise "Bad key: #{key}"
      end
    end

    structure
  end

  def new_fuzzer(entry_point, source)
    GraphQLFuzzer.new(source: source, entry_point: entry_point, current_depth: @current_depth + 1, maximum_depth: @maximum_depth)
  end

  def random_subset(things, &block)
    number = (rand(things.length) * limiting_factor).round
    number = 1 if number < 1
    things.sample(number).each(&block)
  end

  def random_superset(things, &block)
    number = (rand(things.length) * rand * limiting_factor).round
    number = 0 if number < 0
    (things + things.sample(number)).shuffle.each(&block)
  end

  def limiting_factor
    1.0 - (@current_depth.to_f / @maximum_depth)
  end
end
