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

DB.drop_table? :tracks
DB.drop_table? :albums
DB.drop_table? :artists

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

class Artist < Sequel::Model
  one_to_many :albums
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks
  one_to_one(:first_track, class_name: :Track){|ds| ds.where(number: 1)}
end

class Track < Sequel::Model
  many_to_one :album
end

# Simple way to spec what queries are being run.
$sqls = []
$track_sqls = false

logger = Object.new

def logger.info(sql)
  if $track_sqls && q = sql[/\(\d\.[\d]{6,6}s\) (.+)/, 1]
    $sqls << q
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

class PrelaySpec < Minitest::Spec
  include Minitest::Hooks

  def around
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super }
  end

  def execute_query(graphql)
    $sqls.clear
    $track_sqls = true
    GraphQLSchema.execute(graphql, debug: true)
  ensure
    $track_sqls = false
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
    association :first_track
  end

  class Track < Prelay::Model
    model ::Track

    description "A song on an album"

    attribute :name,   type: :string
    attribute :number, type: :integer

    association :album
  end

  GraphQLSchema = Prelay::Schema.new(models: [Artist, Album, Track]).to_graphql_schema(prefix: 'Client')
end
