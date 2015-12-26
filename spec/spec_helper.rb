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

class PrelaySpec < Minitest::Spec
  class Artist < Prelay::Model
    description "A musician with at least one released album"

    attribute :name, type: :string

    association :albums
  end

  class Album < Prelay::Model
    attribute :name, type: :string

    association :artist
    association :tracks
  end

  class Track < Prelay::Model
    attribute :name,   type: :string
    attribute :number, type: :integer

    association :album
  end
end
