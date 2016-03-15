# frozen_string_literal: true

# A custom GraphQL type to handle serialization of timestamps in ISO 8601.

require 'time' # Necessary for Time#iso8601

module Prelay
  TimeType = GraphQL::ScalarType.define do
    name "Timestamp"
    description "Time and date in ISO 8601"

    coerce_input ->(value) { Time.iso8601(value) }
    coerce_result ->(value) { value.iso8601 }
  end
end
