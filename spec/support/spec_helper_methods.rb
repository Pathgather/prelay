# frozen_string_literal: true

module SpecHelperMethods
  def execute_query(graphql)
    sqls.clear
    self.track_sqls = true
    @result = PrelaySpec::GraphQLSchema.execute(graphql, debug: true)
  ensure
    self.track_sqls = false
  end

  def assert_invalid_query(message, graphql)
    error = assert_raises(Prelay::InvalidGraphQLQuery) { execute_query(graphql) }
    assert_equal message, error.message
  end

  def assert_result(data)
    assert_equal data, @result
  end

  def assert_sqls(expected)
    assert_equal expected, sqls
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
    Base64.strict_encode64(args.to_json)
  end

  def encode(type, id)
    Base64.strict_encode64 "#{type}:#{id}"
  end
end
