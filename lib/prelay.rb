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

  class InvalidGraphQLQuery < StandardError; end
end

require 'prelay/dataset_resolver'
require 'prelay/graphql_processor'
require 'prelay/id'
require 'prelay/relay_processor'
require 'prelay/result_array'
require 'prelay/schema'
require 'prelay/selection'
require 'prelay/sequel_connection'
require 'prelay/type'
require 'prelay/version'

GraphQL::Relay::BaseConnection.register_connection_implementation Prelay::ResultArray, Prelay::SequelConnection
