# frozen_string_literal: true

class ReleaseInterface < Prelay::Interface
  description "A collection of songs released by an artist."

  string  :name,         "The name of the release"
  integer :upvotes,      "How many people voted up the release."
  boolean :high_quality, "Whether the release is good or not."
  float   :popularity,   "The normalized popularity of the release, on a scale from 0 to 1."

  many_to_one :artist,    "The artist who released the release.", target: :ArtistType, nullable: false
  one_to_many :tracks,    "The tracks on this release.", target: :TrackType
  one_to_one  :publisher, "The publisher responsible for releasing the release.", target: :PublisherType, nullable: true
end

class GenreType < Prelay::Type
  model Genre

  description "A genre of music"

  string :name, "The genre's name"

  one_to_many :artists, "Artists who predominantly worked in this genre of music."
end

class ArtistType < Prelay::Type
  model Artist

  description "A musician"

  string  :first_name, "The first name of the artist"
  string  :last_name,  "The last name of the artist"
  integer :upvotes,    "How many upvotes the artist got"
  boolean :active,     "Whether the artist is still making music"
  float   :popularity, "The artist's relative popularity, normalized between 0 and 1."

  many_to_one :genre,  "The genre of music the artist predominantly worked in", nullable: false
  one_to_many :albums, "Albums released by the artist"
  one_to_many :releases, "Albums and Compilations released by the artist", order: Sequel.desc(:release_date), target: :ReleaseInterface, foreign_key: :artist_id
end

class AlbumType < Prelay::Type
  model Album
  interface ReleaseInterface, :release_id

  description "An album released by a musician"

  string  :name,         "The name of the album"
  integer :upvotes,      "How many people voted up the album."
  boolean :high_quality, "Whether the album is good or not."
  float   :popularity,   "The normalized popularity of the album, on a scale from 0 to 1."

  many_to_one :artist,    "The artist who released the album.", nullable: false
  one_to_many :tracks,    "The tracks on this album."
  one_to_one  :publisher, "The publisher responsible for releasing the album.", nullable: true

  one_to_one  :first_track,       "The first track on the album.", nullable: true
  one_to_many :first_five_tracks, "The first five tracks on the album"

  filter(:are_high_quality) { |ds| ds.where(:high_quality) }
  filter(:upvotes_greater_than, :integer) { |ds, count| ds.where{upvotes > count} }
end

class CompilationType < Prelay::Type
  model Compilation
  interface ReleaseInterface, :release_id

  description "A release of an artist's best songs"

  string  :name,         "The name of the compilation"
  integer :upvotes,      "How many people voted up the compilation."
  boolean :high_quality, "Whether the compilation is good or not."
  float   :popularity,   "The normalized popularity of the compilation, on a scale from 0 to 1."

  many_to_one :artist,    "The artist who released the compilation.", nullable: false
  one_to_many :tracks,    "The tracks on this compilation."
  one_to_one  :publisher, "The publisher responsible for releasing the compilation.", nullable: true
end

class TrackType < Prelay::Type
  model Track

  description "A song on an album"

  string  :name,         "The name of the track."
  integer :number,       "The number of the track listing."
  boolean :high_quality, "Whether the track is good or not."
  float   :popularity,   "The normalized popularity of the track, on a scale from 0 to 1."

  many_to_one :release, "The release the track belongs to.", target: :ReleaseInterface, nullable: false
end

class PublisherType < Prelay::Type
  model Publisher

  description "The publishing company for an album"

  string :name, "The name of the company."

  many_to_one :album, "The album this company was responsible for.", nullable: false
end
