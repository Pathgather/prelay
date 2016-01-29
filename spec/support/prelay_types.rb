# frozen_string_literal: true

class ReleaseInterface < Prelay::Interface
  description "A collection of songs released by an artist."

  attribute :name,         "The name of the release", datatype: :string
  attribute :upvotes,      "How many people voted up the release.", datatype: :integer
  attribute :high_quality, "Whether the release is good or not.", datatype: :boolean
  attribute :popularity,   "The normalized popularity of the release, on a scale from 0 to 1.", datatype: :float

  many_to_one :artist,    "The artist who released the release.", target: :"PrelaySpec::ArtistType", nullable: false
  one_to_many :tracks,    "The tracks on this release.", target: :"PrelaySpec::TrackType"
  one_to_one  :publisher, "The publisher responsible for releasing the release.", target: :"PrelaySpec::PublisherType", nullable: true
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
  interface ReleaseInterface

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

# For specs on types on models that are on arbitrary datasets.
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

class CompilationType < Prelay::Type
  model Compilation
  interface ReleaseInterface

  description "A release of an artist's best songs"

  attribute :name,         "The name of the compilation", datatype: :string
  attribute :upvotes,      "How many people voted up the compilation.", datatype: :integer
  attribute :high_quality, "Whether the compilation is good or not.", datatype: :boolean
  attribute :popularity,   "The normalized popularity of the compilation, on a scale from 0 to 1.", datatype: :float

  many_to_one :artist,    "The artist who released the compilation.", nullable: false
  one_to_many :tracks,    "The tracks on this compilation."
  one_to_one  :publisher, "The publisher responsible for releasing the compilation.", nullable: true
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
