# frozen_string_literal: true

module SchemaMocking
  attr_reader :schema

  def setup
    @schema = Prelay::Schema.new(temporary: true)

    release_interface = Prelay::Interface(schema: @schema)
    genre_type        = Prelay::Type(schema: @schema)
    artist_type       = Prelay::Type(schema: @schema)
    album_type        = Prelay::Type(schema: @schema)
    compilation_type  = Prelay::Type(schema: @schema)
    track_type        = Prelay::Type(schema: @schema)
    publisher_type    = Prelay::Type(schema: @schema)

    release_interface.class_eval do
      name "Release"
      description "A collection of songs released by an artist."

      string  :name,         "The name of the release"
      integer :upvotes,      "How many people voted up the release."
      boolean :high_quality, "Whether the release is good or not."
      float   :popularity,   "The normalized popularity of the release, on a scale from 0 to 1."

      many_to_one :artist,    "The artist who released the release.", target: artist_type, nullable: false, local_column: :artist_id, remote_column: :id
      one_to_many :tracks,    "The tracks on this release.", target: track_type, order: :created_at, local_column: :id, remote_column: :release_id
    end

    genre_type.class_eval do
      name "Genre"

      model ::Genre

      description "A genre of music"

      string :name, "The genre's name"

      one_to_many :artists, "Artists who predominantly worked in this genre of music.", order: :created_at
    end

    artist_type.class_eval do
      name "Artist"
      model ::Artist

      description "A musician"

      string  :first_name, "The first name of the artist"
      string  :last_name,  "The last name of the artist"
      integer :upvotes,    "How many upvotes the artist got"
      boolean :active,     "Whether the artist is still making music"
      float   :popularity, "The artist's relative popularity, normalized between 0 and 1."

      many_to_one :genre,  "The genre of music the artist predominantly worked in", nullable: true
      one_to_many :albums, "Albums released by the artist", order: :created_at
      one_to_many :releases, "Albums and Compilations released by the artist", order: :created_at, target: release_interface, remote_column: :artist_id
    end

    album_type.class_eval do
      name "Album"
      model ::Album
      interface release_interface

      description "An album released by a musician"

      string  :name,         "The name of the album"
      integer :upvotes,      "How many people voted up the album."
      boolean :high_quality, "Whether the album is good or not."
      float   :popularity,   "The normalized popularity of the album, on a scale from 0 to 1."

      many_to_one :artist,    "The artist who released the album.", nullable: false
      one_to_many :tracks,    "The tracks on this album.", order: :created_at
      one_to_one  :publisher, "The publisher responsible for releasing the album.", nullable: true

      one_to_one  :first_track,       "The first track on the album.", nullable: true
      one_to_many :first_five_tracks, "The first five tracks on the album", order: :created_at
    end

    compilation_type.class_eval do
      name "Compilation"
      model ::Compilation
      interface release_interface

      description "A release of an artist's best songs"

      string  :name,         "The name of the compilation"
      integer :upvotes,      "How many people voted up the compilation."
      boolean :high_quality, "Whether the compilation is good or not."
      float   :popularity,   "The normalized popularity of the compilation, on a scale from 0 to 1."

      many_to_one :artist, "The artist who released the compilation.", nullable: false
      one_to_many :tracks, "The tracks on this compilation.", order: :created_at
    end

    track_type.class_eval do
      name "Track"
      model ::Track

      description "A song on an album"

      string  :name,         "The name of the track."
      integer :number,       "The number of the track listing."
      boolean :high_quality, "Whether the track is good or not."
      float   :popularity,   "The normalized popularity of the track, on a scale from 0 to 1."

      many_to_one :release, "The release the track belongs to.", target: release_interface, nullable: false, local_column: :release_id
    end

    publisher_type.class_eval do
      name "Publisher"
      model ::Publisher

      description "The publishing company for an album"

      string :name, "The name of the company."

      many_to_one :album, "The album this company was responsible for.", nullable: false
    end

    target_class = self.class

    until target_class.superclass == PrelaySpec
      target_class = target_class.superclass
    end

    target_class.const_set(:ReleaseInterface, release_interface)
    target_class.const_set(:GenreType,        genre_type)
    target_class.const_set(:ArtistType,       artist_type)
    target_class.const_set(:AlbumType,        album_type)
    target_class.const_set(:CompilationType,  compilation_type)
    target_class.const_set(:TrackType,        track_type)
    target_class.const_set(:PublisherType,    publisher_type)

    super
  end

  def teardown
    super

    target_class = self.class

    until target_class.superclass == PrelaySpec
      target_class = target_class.superclass
    end

    target_class.send :remove_const, :ReleaseInterface
    target_class.send :remove_const, :GenreType
    target_class.send :remove_const, :ArtistType
    target_class.send :remove_const, :AlbumType
    target_class.send :remove_const, :CompilationType
    target_class.send :remove_const, :TrackType
    target_class.send :remove_const, :PublisherType
  end

  def self.included(base)
    base.extend Module.new {
      def mock_schema(&block)
        prepend Module.new {
          define_method :setup do
            super()
            SchemaMocker.new(@schema).instance_eval(&block)
          end
        }
      end
    }
  end

  class SchemaMocker
    def initialize(schema)
      @schema = schema
    end

    def type(name, &block)
      mock(:Type, name, definition: block) do |c|
        c.model(Kernel.const_get("::#{name}", false))
      end
    end

    def interface(name, &block)
      mock(:Interface, name, definition: block)
    end

    def query(name, &block)
      mock(:Query, name, definition: block)
    end

    def mutation(name, &block)
      mock(:Mutation, name, definition: block)
    end

    private

    def mock(meth, name, definition:, &block)
      superclass = Prelay.method(meth).call(schema: @schema)
      c = Class.new(superclass)
      c.name(name.to_s)
      yield c if block_given?
      c.class_eval(&definition) if definition
      c
    end
  end
end
