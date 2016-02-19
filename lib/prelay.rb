# frozen_string_literal: true

require 'sequel'
require 'sequel-seek-pagination'

require 'graphql'
require 'graphql/relay'

Sequel::Database.extension :seek_pagination

module Prelay
  # Frozen empty objects, mostly for use as argument defaults. Makes sure that
  # we don't accidentally modify arguments passed to our methods, and cuts
  # down on the number of allocated objects.
  EMPTY_ARRAY = [].freeze
  EMPTY_HASH  = {}.freeze

  # Array of all permanent Prelay schemas that have been instantiated.
  SCHEMAS = []

  class InvalidGraphQLQuery < StandardError; end
  class DefinitionError < StandardError; end

  %w(Type Interface Query Mutation).each do |subclassable|
    eval <<-RUBY
      def self.#{subclassable}(schema:)
        c = Class.new(#{subclassable})
        c.schema = schema
        c
      end
    RUBY
  end
end

require 'prelay/schema'
require 'prelay/subclassable'

require 'prelay/type'
require 'prelay/interface'
require 'prelay/query'
require 'prelay/mutation'

require 'prelay/graphql_processor'
require 'prelay/relay_processor'
require 'prelay/selection'

require 'prelay/dataset_resolver'
require 'prelay/sequel_connection'
require 'prelay/result_array'

require 'prelay/connection'
require 'prelay/id'
require 'prelay/time_type'

require 'prelay/version'

GraphQL::Relay::BaseConnection.register_connection_implementation Prelay::ResultArray, Prelay::SequelConnection
