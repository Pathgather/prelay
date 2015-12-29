$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

require 'faker'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///prelay-test')

DB.extension :pg_json

DB.run <<-SQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA pg_catalog;
SQL

DB.drop_table? :publishers, :tracks, :albums, :artists

DB.create_table :artists do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  text        :name,       null: false
  integer     :upvotes,    null: false
  boolean     :active,     null: false
  float       :popularity, null: false
  date        :birth_date, null: false
  numeric     :money_made, null: false
  jsonb       :other,      null: false
  timestamptz :created_at, null: false
end

DB.create_table :albums do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :artist_id, null: false

  text        :name,         null: false
  integer     :upvotes,      null: false
  boolean     :high_quality, null: false
  float       :popularity,   null: false
  date        :release_date, null: false
  numeric     :money_made,   null: false
  jsonb       :other,        null: false
  timestamptz :created_at,   null: false

  foreign_key [:artist_id], :artists
end

DB.create_table :tracks do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  text        :name,         null: false
  integer     :number,       null: false
  boolean     :high_quality, null: false
  float       :popularity,   null: false
  date        :single_date,  null: false
  numeric     :money_made,   null: false
  jsonb       :other,        null: false
  timestamptz :created_at,   null: false

  unique [:album_id, :number]
  foreign_key [:album_id], :albums
end

DB.create_table :publishers do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  text :name, null: false

  foreign_key [:album_id], :albums

  unique :album_id
end

# # A little helper to raise a nice error if any of our specs try to access a
# # model attribute that wasn't loaded from the DB. Probably not a good idea
# # to use it all the time, but it's useful for linting every once in a while.
# Sequel::Model.send :include, Module.new {
#   def [](k)
#     @values.fetch(k) { raise "column '#{k}' not loaded for object #{inspect}" }
#   end
# }

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

def random_json_value
  case rand
  when 0.00..0.30 then rand 100000                             # Integer
  when 0.30..0.60 then Faker::Lorem.sentence                   # String
  when 0.60..0.70 then rand > 0.5                              # Boolean
  when 0.70..0.80 then rand * 10000                            # Float
  when 0.80..0.90 then nil                                     # Null
  when 0.90..0.95 then rand(4).times.map { random_json_value } # Array (uncommon)
  when 0.95..1.00 then random_json_doc                         # Doc (uncommon)
  else raise "Oops!"
  end
end

def random_json_doc
  output = {}
  Faker::Lorem.words(rand(6)).each do |word|
    output[word.downcase] = random_json_value
  end
  output
end

artist_ids = DB[:artists].multi_insert(
  25.times.map {
    {
      name:       Faker::Name.name,
      upvotes:    rand(10000),
      active:     rand > 0.5,
      popularity: rand,
      birth_date: Date.today - (7200 + rand(20000)),
      money_made: (rand * 1000000).round(2),
      other:      Sequel.pg_jsonb(random_json_doc),
      created_at: Time.now - (rand(1000) * 24 * 60 * 60),
    }
  },
  return: :primary_key
)

album_ids = DB[:albums].multi_insert(
  artist_ids.map { |artist_id|
    10.times.map {
      {
        artist_id:    artist_id,
        name:         Faker::Lorem.sentence,
        upvotes:      rand(10000),
        high_quality: rand > 0.9,
        popularity:   rand,
        release_date: Date.today - rand(1000),
        money_made:   (rand * 100000).round(2),
        other:        Sequel.pg_jsonb(random_json_doc),
        created_at:   Time.now - (rand(1000) * 24 * 60 * 60),
      }
    }
  }.flatten(1),
  return: :primary_key
)

track_ids = DB[:tracks].multi_insert(
  album_ids.map { |album_id|
    10.times.map { |i|
      {
        album_id:     album_id,
        name:         Faker::Lorem.sentence,
        number:       i + 1,
        high_quality: rand > 0.9,
        popularity:   rand,
        single_date:  Date.today - rand(1000),
        money_made:   (rand * 10000).round(2),
        other:        Sequel.pg_jsonb(random_json_doc),
        created_at:   Time.now - (rand(1000) * 24 * 60 * 60),
      }
    }
  }.flatten(1),
  return: :primary_key
)

publisher_ids = DB[:publishers].multi_insert(
  album_ids.map { |album_id|
    {
      album_id: album_id,
      name:     Faker::Company.name
    }
  },
  return: :primary_key
)

class PrelaySpec < Minitest::Spec
  ENV['N'] = '4'
  parallelize_me!
  make_my_diffs_pretty!

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

    attribute :name,       type: :string
    attribute :upvotes,    type: :integer
    attribute :active,     type: :boolean
    attribute :popularity, type: :float

    association :albums
  end

  class Album < Prelay::Model
    model ::Album

    description "An album released by a musician"

    attribute :name,         type: :string
    attribute :upvotes,      type: :integer
    attribute :high_quality, type: :boolean
    attribute :popularity,   type: :float

    association :artist
    association :tracks
    association :publisher
  end

  class Track < Prelay::Model
    model ::Track

    description "A song on an album"

    attribute :name,         type: :string
    attribute :number,       type: :integer
    attribute :high_quality, type: :boolean
    attribute :popularity,   type: :float

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
