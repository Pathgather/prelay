# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

require 'faker'
require 'pry'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///prelay-test')

DB.extension :pg_json

DB.run <<-SQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA pg_catalog;
SQL

DB.drop_table? :publishers, :tracks, :albums, :artists, :genres

DB.create_table :genres do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  text :name, null: false
end

DB.create_table :artists do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :genre_id # Nullable

  text        :first_name, null: false
  text        :last_name,  null: false
  integer     :upvotes,    null: false
  boolean     :active,     null: false
  float       :popularity, null: false
  date        :birth_date, null: false
  numeric     :money_made, null: false
  jsonb       :other,      null: false
  timestamptz :created_at, null: false

  foreign_key [:genre_id], :genres
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

class Genre < Sequel::Model
  one_to_many :artists
end

class Artist < Sequel::Model
  many_to_one :genre
  one_to_many :albums, order: Sequel.desc(:release_date)

  def name
    "#{first_name} #{last_name}"
  end
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks, order: :number
  one_to_one :publisher

  one_to_one  :first_track,       class_name: :Track, &:is_first
  one_to_many :first_five_tracks, class_name: :Track, order: :number, &:in_first_five
end

class BestAlbum < Sequel::Model(DB[:albums].where(:high_quality))
  many_to_one :artist
  one_to_many :tracks, key: :album_id
  one_to_one :publisher, key: :album_id

  one_to_one  :first_track,       class_name: :Track, key: :album_id, &:is_first
  one_to_many :first_five_tracks, class_name: :Track, key: :album_id, &:in_first_five
end

class Track < Sequel::Model
  many_to_one :album

  subset :is_first,      number: 1
  subset :in_first_five, number: 1..5
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

genre_ids = DB[:genres].multi_insert(
  Faker::Lorem.words(5).map { |word|
    {
      name: word
    }
  },
  return: :primary_key
)

artist_ids = DB[:artists].multi_insert(
  25.times.map {
    {
      genre_id:   (genre_ids.sample if rand > 0.5),
      first_name: Faker::Name.first_name,
      last_name:  Faker::Name.last_name,
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
    @result = GraphQLSchema.execute(graphql, debug: true)
  ensure
    self.track_sqls = false
  end

  def assert_invalid_query(message, graphql)
    error = assert_raises(Prelay::InvalidGraphQLQuery) { execute_query(graphql) }
    assert_equal message, error.message
  end

  def assert_result(data)
    assert_equal data, @result
  end

  def assert_sqls(expected)
    assert_equal expected, sqls
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

  def encode(*args)
    self.class.encode(*args)
  end

  def to_cursor(*args)
    Base64.strict_encode64(args.to_json)
  end

  def graphql_args(input)
    # GraphQL input syntax is basically JSON with unquoted keys.
    input.map{|k,v| "#{k}: #{v.inspect}"}.join(', ')
  end

  class << self
    def encode(type, id)
      Base64.strict_encode64 "#{type}:#{id}"
    end
  end

  class GenreType < Prelay::Type
    model Genre

    description "A genre of music"

    attribute :name, "The genre's name", datatype: :string

    one_to_many :artists, "Artists who predominantly worked in this genre of music."
  end

  class ArtistType < Prelay::Type
    model Artist

    description "A musician"

    attribute :name,       "The full name of the artist", datatype: :string, dependent_columns: [:first_name, :last_name]
    attribute :upvotes,    "How many upvotes the artist got", datatype: :integer
    attribute :active,     "Whether the artist is still making music", datatype: :boolean
    attribute :popularity, "The artist's relative popularity, normalized between 0 and 1.", datatype: :float

    many_to_one :genre,  "The genre of music the artist predominantly worked in", nullable: false
    one_to_many :albums, "Albums released by the artist"
  end

  class AlbumType < Prelay::Type
    model Album

    description "An album released by a musician"

    attribute :name,         "The name of the album", datatype: :string
    attribute :upvotes,      "How many people voted up the album.", datatype: :integer
    attribute :high_quality, "Whether the album is good or not.", datatype: :boolean
    attribute :popularity,   "The normalized popularity of the album, on a scale from 0 to 1.", datatype: :float

    many_to_one :artist,    "The artist who released the album.", nullable: false
    one_to_many :tracks,    "The tracks on this album."
    one_to_one  :publisher, "The publisher responsible for releasing the album.", nullable: true

    one_to_one  :first_track,       "The first track on the album.", nullable: true
    one_to_many :first_five_tracks, "The first five tracks on the album"
  end

  class BestAlbumType < Prelay::Type
    model BestAlbum

    description "A good album released by a musician"

    attribute :name,         "The name of the album", datatype: :string
    attribute :upvotes,      "How many people voted up the album.", datatype: :integer
    attribute :high_quality, "Whether the album is good or not.", datatype: :boolean
    attribute :popularity,   "The normalized popularity of the album, on a scale from 0 to 1.", datatype: :float

    many_to_one :artist,    "The artist who released the album.", nullable: false
    one_to_many :tracks,    "The tracks on this album."
    one_to_one  :publisher, "The publisher responsible for releasing the album.", nullable: true

    one_to_one  :first_track,       "The first track on the album.", nullable: true
    one_to_many :first_five_tracks, "The first five tracks on the album"
  end

  class TrackType < Prelay::Type
    model Track

    description "A song on an album"

    attribute :name,         "The name of the track.", datatype: :string
    attribute :number,       "The number of the track listing.", datatype: :integer
    attribute :high_quality, "Whether the track is good or not.", datatype: :boolean
    attribute :popularity,   "The normalized popularity of the track, on a scale from 0 to 1.", datatype: :float

    many_to_one :album, "The album the track belongs to.", nullable: false
  end

  class PublisherType < Prelay::Type
    model Publisher

    description "The publishing company for an album"

    attribute :name, "The name of the company.", datatype: :string

    many_to_one :album, "The album this company was responsible for.", nullable: false
  end

  GraphQLSchema = Prelay::Schema.new(
    types: [ArtistType, AlbumType, BestAlbumType, TrackType, PublisherType, GenreType]
  ).to_graphql_schema(prefix: 'Client')
end
