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
