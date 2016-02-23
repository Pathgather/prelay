# frozen_string_literal: true

# A custom GraphQL type to handle serialization of timestamps in ISO 8601.

require 'time' # Necessary for Time#iso8601

module Prelay
  TimeType = GraphQL::ScalarType.define do
    name "Timestamp"
    description "Time and date in ISO 8601"

    coerce_input ->(value) {
      # Looks like if the client is fine with sending it, we can use Time.iso8601(value).
      raise Error, "Input syntax for Time objects not finalized yet"
    }
    coerce_result ->(value) { value.iso8601 }
  end
end
