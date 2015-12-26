$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres:///prelay-test')

DB.run <<-SQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA pg_catalog;
SQL

DB.drop_table? :tracks
DB.drop_table? :albums
DB.drop_table? :artists

DB.create_table :artists do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  text :name
end

DB.create_table :albums do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :artist_id, null: false

  foreign_key [:artist_id], :artists

  text :name
end

DB.create_table :tracks do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  foreign_key [:album_id], :albums

  text :name
  integer :number
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

DB.loggers << logger

music =
  [
    {
      name: "Kaki King",
      albums: [
        {
          name: "Glow",
          tracks: ["Great Round Burn", "StreetLight In The Egg", "Bowen Island", "Cargo Cult", "Kelvinator, Kelvinator", "Fences", "No True Masterpiece Will Ever Be Complete", "Holding The Severed Self", "Skimming The Fractured Surface To A Place Of Endless Light", "King Pitzel", "The Fire Eater", "Marche Slav"]
        },
        {
          name: "Dreaming of Revenge",
          tracks: ["Bone Chaos In The Castle", "Life Being What It Is", "Sad American", "Pull Me Out Alive", "Montreal", "Open Mouth", "So Much For So Little", "Saving Days In A Frozen Head", "Air and Kilometers", "Can Anyone Who Has Heard This Music Really Be A Bad Person?", "2 O'Clock"]
        },
      ]
    },
    {
      name: "The War On Drugs",
      albums: [
        {
          name: "Lost in the Dream",
          tracks: ["Under the Pressure", "Red Eyes", "Suffering", "An Ocean Between The Waves", "Disappearing", "Eyes to the Wind", "The Haunting Idle", "Burning", "Lost in the Dream", "In Reverse"]
        }
      ]
    },
    {
      name: "Carly Rae Jepsen",
      albums: [
        {
          name: "Emotion",
          tracks: ["Run Away With Me", "Emotion", "I Really Like You", "Gimmie Love", "All That", "Boy Problems", "Making The Most Of The Night", "Your Type", "Let's Get Lost", "LA Hallucinations", "Warm Blood", "When I Needed You"]
        },
        {
          name: "Kiss",
          tracks: ["Tiny Little Bows", "This Kiss", "Call Me Maybe", "Curiosity", "Good Time", "More Than A Memory", "Turn Me Up", "Hurt So Good", "Beautiful", "Tonight I'm Getting Over You", "Guitar String/Wedding Ring", "Your Heart is a Muscle", "I Know You Have A Girlfriend"]
        }
      ]
    }
  ]

music.each do |artist_attrs|
  artist = Artist.create(name: artist_attrs[:name])
  artist_attrs[:albums].each do |album_attrs|
    album = Album.create(name: album_attrs[:name], artist: artist)
    album_attrs[:tracks].each_with_index do |name, i|
      Track.create(name: name, number: i + 1, album: album)
    end
  end
end

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
