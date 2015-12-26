$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'prelay'

require 'minitest/autorun'
require 'minitest/pride'

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
end

class Track < Sequel::Model
  many_to_one :album
end

# Simple way to spec what queries are being run.
$sqls = []

logger = Object.new
def logger.info(sql)
  if q = sql[/\(\d\.[\d]{6,6}s\) (.+)/, 1]
    $sqls << q
  end
end

DB.loggers << logger

class PrelaySpec < Minitest::Spec
  def setup
    $sqls.clear
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
