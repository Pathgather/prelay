# frozen_string_literal: true

puts "Rebuilding Prelay Test DB..."

DB.drop_table? :publishers, :tracks, :compilations, :albums, :artists, :genres

DB.run <<-SQL
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA pg_catalog;
SQL

DB.create_table :genres do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  text :name, null: false
end

DB.create_table :artists do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :genre_id # Nullable

  text        :first_name, null: false
  text        :last_name,  null: false
  integer     :upvotes,    null: false, default: 0
  boolean     :active,     null: false, default: true
  float       :popularity, null: false, default: Sequel.function(:random)
  date        :birth_date, null: false, default: Sequel::CURRENT_DATE
  numeric     :money_made, null: false, default: Sequel.function(:random) * 1000
  jsonb       :other,      null: false, default: Sequel.pg_jsonb({})
  timestamptz :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

  foreign_key [:genre_id], :genres
end

DB.create_table :albums do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :artist_id, null: false

  text        :name,         null: false
  integer     :upvotes,      null: false, default: 0
  boolean     :high_quality, null: false, default: false
  float       :popularity,   null: false, default: Sequel.function(:random)
  date        :release_date, null: false, default: Sequel::CURRENT_DATE
  numeric     :money_made,   null: false, default: Sequel.function(:random) * 1000
  jsonb       :other,        null: false, default: Sequel.pg_jsonb({})
  timestamptz :created_at,   null: false, default: Sequel::CURRENT_TIMESTAMP

  foreign_key [:artist_id], :artists
end

DB.create_table :compilations do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :artist_id, null: false

  text        :name,         null: false
  integer     :upvotes,      null: false, default: 0
  boolean     :high_quality, null: false, default: false
  float       :popularity,   null: false, default: Sequel.function(:random)
  date        :release_date, null: false, default: Sequel::CURRENT_DATE
  numeric     :money_made,   null: false, default: Sequel.function(:random) * 1000
  jsonb       :other,        null: false, default: Sequel.pg_jsonb({})
  timestamptz :created_at,   null: false, default: Sequel::CURRENT_TIMESTAMP

  foreign_key [:artist_id], :artists
end

DB.create_table :tracks do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  # Polymorphic setup - a track can belong to an album XOR a compilation.
  uuid :release_id, null: false
  uuid :album_id
  uuid :compilation_id

  constraint(:compilation_presence) { Sequel.~({{album_id: nil} => {compilation_id: nil}}) }
  constraint(:compilation_validity) { {release_id: coalesce(:album_id, :compilation_id)} }

  text        :name,         null: false
  integer     :number,       null: false
  boolean     :high_quality, null: false, default: false
  float       :popularity,   null: false, default: Sequel.function(:random)
  date        :single_date,  null: false, default: Sequel::CURRENT_DATE
  numeric     :money_made,   null: false, default: Sequel.function(:random) * 1000
  jsonb       :other,        null: false, default: Sequel.pg_jsonb({})
  timestamptz :created_at,   null: false, default: Sequel::CURRENT_TIMESTAMP

  unique [:release_id, :number]
  index  [:album_id]
  index  [:compilation_id]

  foreign_key [:album_id],       :albums
  foreign_key [:compilation_id], :compilations
end

DB.create_table :publishers do
  uuid :id, primary_key: true, default: Sequel.function(:uuid_generate_v4)

  uuid :album_id, null: false

  text :name, null: false

  foreign_key [:album_id], :albums

  unique :album_id
end
