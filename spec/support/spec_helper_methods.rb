# frozen_string_literal: true

module SpecHelperMethods
  # We often assert_equal() deeply nested hash structures, to make sure that
  # we're returning the correct JSON output, but Minitest's built-in diffing
  # doesn't special-case hashes, so normal variations in key order are
  # flagged. To get around this, deep-sort hashes by their keys when diffing.
  def diff(a, b)
    if a.is_a?(Hash) && b.is_a?(Hash)
      super(sort_hash(a), sort_hash(b))
    else
      super
    end
  end

  def sort_hash(t)
    case t
    when Hash  then t.sort_by(&:first).map{|k,v| [k, sort_hash(v)]}.to_h
    when Array then t.map { |e| sort_hash(e) }
    else t
    end
  end

  def execute_query(graphql)
    sqls.clear
    self.track_sqls = true
    @result = schema.graphql_schema.execute(graphql, debug: true)
    assert_nil @result['errors']
  ensure
    self.track_sqls = false
  end

  def execute_mutation(name, graphql: '', fragments: [])
    assert_instance_of Hash, @input

    @mutation_name = name.to_s

    @input[:clientMutationId] ||= SecureRandom.uuid

    @client_mutation_id = @input[:clientMutationId]

    execute_query <<-GRAPHQL
      mutation Mutation {
        #{name}(input: {#{graphql_args(@input)}}) {
          clientMutationId,
          #{graphql}
        }
      }
      #{fragments.join("\n")}
    GRAPHQL

    assert_equal @client_mutation_id, @result['data'][@mutation_name]['clientMutationId']
  end

  def assert_result(data)
    assert_equal data, @result
  end

  def assert_invalid_query(message, graphql)
    error = assert_raises(Prelay::Error) { execute_query(graphql) }
    assert_equal message, error.message
  end

  def assert_mutation_result(data)
    assert_result \
      'data' => { @mutation_name => data.merge('clientMutationId' => @client_mutation_id) }
  end

  def assert_sqls(expected)
    actual = sqls

    assert_equal expected, actual unless expected.length == actual.length

    expected.zip(actual).each do |e, a|
      case e
      when String then assert_equal(e, a)
      when Regexp then assert_match(e, a)
      else raise "Unexpected argument to assert_sqls: #{e.inspect}"
      end
    end
  end

  def sqls
    Thread.current[:sqls] ||= []
  end

  def track_sqls?
    Thread.current[:track_sqls]
  end

  def track_sqls=(boolean)
    Thread.current[:track_sqls] = boolean
  end

  def graphql_args(input)
    # GraphQL input syntax is basically JSON with unquoted keys.
    input.map{|k,v| "#{k}: #{v.inspect}"}.join(', ')
  end

  def to_cursor(*args)
    args = args.map do |thing|
      case thing
      when Time then [thing.to_i, thing.usec]
      else thing
      end
    end

    Base64.strict_encode64(args.to_json)
  end

  def id_for(object)
    encode_prelay_id type: type_name_for(object), pk: object.pk
  end

  def type_for(object)
    schema.type_for_model!(object.class)
  end

  def type_name_for(object)
    type_for(object).graphql_object.to_s
  end

  def encode_prelay_id(type:, pk:)
    Base64.strict_encode64 "#{type}:#{pk}"
  end
end
