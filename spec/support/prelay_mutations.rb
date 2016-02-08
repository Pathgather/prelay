# frozen_string_literal: true

class UpdateAlbumMutation < Prelay::Mutation
  description <<-DESC

    Updates an album with the given id.

  DESC

  argument :id, :id
  argument :name, :text

  result_field :album, association: :self

  type AlbumType

  def mutate(id:, name:)
    album = Prelay::ID.parse(id, expected_type: AlbumType).get

    album.update(name: name)

    {album: album.id}
  end
end

class CreateAlbumMutation < Prelay::Mutation
  description <<-DESC

    Creates an album object given some attributes, including an artist to
    associate it with. Returns an album node and an edge for its association
    to the artist.

  DESC

  type AlbumType

  argument :artist_id, :id
  argument :name,      :text

  result_field :artist,     association: :artist
  result_field :album,      association: :self
  result_field :album_edge, association: :self, edge: true

  def mutate(args)
    args[:artist] = Prelay::ID.parse(args.delete(:artist_id), expected_type: ArtistType).get

    album = Album.new(args)
    album.upvotes = 0
    album.high_quality = true
    album.popularity = 0.5
    album.release_date = Date.today
    album.money_made = 0.0
    album.other = Sequel.pg_json({})
    album.created_at = Date.today.to_time
    album.save

    {artist: album.artist_id, album: album.id}
  end
end
