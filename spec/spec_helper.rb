# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

require 'faker'
require 'pry'

require_relative 'support/connect_db'

if !DB.table_exists?(:publishers) || ENV['PRELAY_REBUILD']
  require_relative 'support/build_db'
  require_relative 'support/populate_db'
end

require_relative 'support/sequel_models'
require_relative 'support/prelay_types'
require_relative 'support/spec_helper_methods'

# # A little helper to raise a nice error if any of our specs try to access a
# # model attribute that wasn't loaded from the DB. Probably not a good idea
# # to use it all the time, but it's useful for linting every once in a while.
# Sequel::Model.send :include, Module.new {
#   def [](k)
#     @values.fetch(k) { raise "column '#{k}' not loaded for object #{inspect}" }
#   end
# }

class PrelaySpec < Minitest::Spec
  ENV['N'] = '4'
  parallelize_me!
  make_my_diffs_pretty!

  include Minitest::Hooks

  include SpecHelperMethods
  extend  SpecHelperMethods

  def around
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super }
  end

  GraphQLSchema = Prelay::Schema.new(
    types: [
      ReleaseInterface,
      ArtistType,
      AlbumType,
      BestAlbumType,
      CompilationType,
      TrackType,
      PublisherType,
      GenreType,
    ]
  ).to_graphql_schema(prefix: 'Client')
end
