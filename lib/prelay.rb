# frozen-string-literal: true

require 'sequel'
require 'sequel-seek-pagination'

require 'graphql'
require 'graphql/relay'

require 'prelay/dataset_resolver'
require 'prelay/id'
require 'prelay/relay_processor'
require 'prelay/schema'
require 'prelay/selection'
require 'prelay/sequel_connection'
require 'prelay/type'
require 'prelay/version'

Sequel::Database.extension :seek_pagination

GraphQL::Relay::BaseConnection.register_connection_implementation Array, Prelay::SequelConnection

module Prelay
  class InvalidGraphQLQuery < StandardError; end
end
