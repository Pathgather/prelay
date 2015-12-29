# frozen-string-literal: true

require 'sequel'
require 'graphql'
require 'graphql/relay'

require 'prelay/dataset_resolver'
require 'prelay/id'
require 'prelay/relay_processor'
require 'prelay/schema'
require 'prelay/selection'
require 'prelay/type'
require 'prelay/version'

module Prelay
  class InvalidGraphQLQuery < StandardError; end
end
