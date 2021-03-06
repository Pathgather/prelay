# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'graphql/libgraphqlparser'

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

# # A little helper to raise a nice error if any of our specs try to access a
# # model attribute that wasn't loaded from the DB. Probably not a good idea
# # to use it all the time, but it's useful for linting every once in a while.
# Sequel::Model.send :include, Module.new {
#   def [](k)
#     @values.fetch(k) { raise "column '#{k}' not loaded for object #{inspect}" }
#   end
# }

require_relative 'support/schema_mocking'
require_relative 'support/spec_helper_methods'

class PrelaySpec < Minitest::Spec
  ENV['N'] = '4'
  # parallelize_me!
  make_my_diffs_pretty!

  include Minitest::Hooks
  include SchemaMocking
  include SpecHelperMethods

  TEST_MUTEX = Mutex.new
  SCHEMA = Prelay::Schema.new

  def around
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super }
  end
end

require_relative 'support/graphql_fuzzer'

require_relative 'support/sequel_models'
