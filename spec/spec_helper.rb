$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

require 'faker'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///prelay-test')

DB.run <<-SQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA pg_catalog;
SQL

DB.drop_table? :publishers, :tracks, :albums, :artists

DB.create_table :artists do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  text :name, null: false
end

DB.create_table :albums do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :artist_id, null: false

  foreign_key [:artist_id], :artists

  text :name, null: false
end

DB.create_table :tracks do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  foreign_key [:album_id], :albums

  text :name, null: false
  integer :number, null: false
end

DB.create_table :publishers do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  foreign_key [:album_id], :albums

  text :name, null: false

  unique :album_id
end

class Artist < Sequel::Model
  one_to_many :albums
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks
  one_to_one :publisher
end

class Track < Sequel::Model
  many_to_one :album
end

class Publisher < Sequel::Model
  many_to_one :album
end

# Simple way to spec what queries are being run.
logger = Object.new

def logger.info(sql)
  if Thread.current[:track_sqls] && q = sql[/\(\d\.[\d]{6,6}s\) (.+)/, 1]
    Thread.current[:sqls] << q
  end
end

def logger.error(msg)
  puts msg
end

DB.loggers << logger

artist_ids = DB[:artists].import(
  [:name],
  25.times.map {
    [Faker::Name.name]
  },
  return: :primary_key
)

album_ids = DB[:albums].import(
  [:artist_id, :name],
  artist_ids.map { |a_id|
    10.times.map {
      [a_id, Faker::Lorem.sentence]
    }
  }.flatten(1),
  return: :primary_key
)

track_ids = DB[:tracks].import(
  [:album_id, :name, :number],
  album_ids.map { |a_id|
    10.times.map { |i|
      [a_id, Faker::Lorem.sentence, i + 1]
    }
  }.flatten(1),
  return: :primary_key
)

publisher_ids = DB[:publishers].import(
  [:album_id, :name],
  album_ids.map { |a_id|
    [a_id, Faker::Company.name]
  },
  return: :primary_key
)

class PrelaySpec < Minitest::Spec
  ENV['N'] = '4'
  parallelize_me!

  include Minitest::Hooks

  def around
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super }
  end

  def execute_query(graphql)
    sqls.clear
    self.track_sqls = true
    GraphQLSchema.execute(graphql, debug: true)
  ensure
    self.track_sqls = false
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

  def execute_invalid_query(graphql)
    assert_raises(Prelay::InvalidGraphQLQuery) { execute_query(graphql) }
  end

  def encode(type, id)
    Base64.strict_encode64 "#{type}:#{id}"
  end

  class Artist < Prelay::Model
    model ::Artist

    description "A musician"

    attribute :name, type: :string

    association :albums
  end

  class Album < Prelay::Model
    model ::Album

    description "An album released by a musician"

    attribute :name, type: :string

    association :artist
    association :tracks
    association :publisher
  end

  class Track < Prelay::Model
    model ::Track

    description "A song on an album"

    attribute :name,   type: :string
    attribute :number, type: :integer

    association :album
  end

  class Publisher < Prelay::Model
    model ::Publisher

    description "The publishing company for an album"

    attribute :name, type: :string

    association :album
  end

  GraphQLSchema = Prelay::Schema.new(
    models: [Artist, Album, Track, Publisher]
  ).to_graphql_schema(prefix: 'Client')
end
