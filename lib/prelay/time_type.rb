# frozen_string_literal: true

# A custom GraphQL type to handle serialization of timestamps in ISO 8601.

require 'time' # Necessary for Time#iso8601

module Prelay
  TimeType = GraphQL::ScalarType.define do
    name "Timestamp"
    description "Time and date in ISO 8601"

    # Special-case empty strings as a way to pass null values to the server,
    # though the GraphQL gem won't actually let us return nil :(
    coerce_input ->(value) { value == '' ? '' : Time.iso8601(value) }
    coerce_result ->(value) { value.iso8601(6) }
  end
end
