# frozen_string_literal: true

class ReleaseInterface < Prelay::Interface
  description "A collection of songs released by an artist."

  attribute :name,         :string,  "The name of the release"
  attribute :upvotes,      :integer, "How many people voted up the release."
  attribute :high_quality, :boolean, "Whether the release is good or not."
  attribute :popularity,   :float,   "The normalized popularity of the release, on a scale from 0 to 1."

  many_to_one :artist,    "The artist who released the release.", target: :ArtistType, nullable: false
  one_to_many :tracks,    "The tracks on this release.", target: :TrackType
  one_to_one  :publisher, "The publisher responsible for releasing the release.", target: :PublisherType, nullable: true
end

class GenreType < Prelay::Type
  model Genre

  description "A genre of music"

  attribute :name, :string, "The genre's name"

  one_to_many :artists, "Artists who predominantly worked in this genre of music."
end

class ArtistType < Prelay::Type
  model Artist

  description "A musician"

  attribute :first_name, :string,  "The first name of the artist"
  attribute :last_name,  :string,  "The last name of the artist"
  attribute :upvotes,    :integer, "How many upvotes the artist got"
  attribute :active,     :boolean, "Whether the artist is still making music"
  attribute :popularity, :float,   "The artist's relative popularity, normalized between 0 and 1."

  many_to_one :genre,  "The genre of music the artist predominantly worked in", nullable: false
  one_to_many :albums, "Albums released by the artist"
  one_to_many :releases, "Albums and Compilations released by the artist", order: Sequel.desc(:release_date), target: :ReleaseInterface, foreign_key: :artist_id
end

class AlbumType < Prelay::Type
  model Album
  interface ReleaseInterface, :release_id

  description "An album released by a musician"

  attribute :name,         :string,  "The name of the album"
  attribute :upvotes,      :integer, "How many people voted up the album."
  attribute :high_quality, :boolean, "Whether the album is good or not."
  attribute :popularity,   :float,   "The normalized popularity of the album, on a scale from 0 to 1."

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

  attribute :name,         :string,  "The name of the compilation"
  attribute :upvotes,      :integer, "How many people voted up the compilation."
  attribute :high_quality, :boolean, "Whether the compilation is good or not."
  attribute :popularity,   :float,   "The normalized popularity of the compilation, on a scale from 0 to 1."

  many_to_one :artist,    "The artist who released the compilation.", nullable: false
  one_to_many :tracks,    "The tracks on this compilation."
  one_to_one  :publisher, "The publisher responsible for releasing the compilation.", nullable: true
end

class TrackType < Prelay::Type
  model Track

  description "A song on an album"

  attribute :name,         :string,  "The name of the track."
  attribute :number,       :integer, "The number of the track listing."
  attribute :high_quality, :boolean, "Whether the track is good or not."
  attribute :popularity,   :float,   "The normalized popularity of the track, on a scale from 0 to 1."

  many_to_one :release, "The release the track belongs to.", target: :ReleaseInterface, nullable: false
end

class PublisherType < Prelay::Type
  model Publisher

  description "The publishing company for an album"

  attribute :name, :string, "The name of the company."

  many_to_one :album, "The album this company was responsible for.", nullable: false
end
