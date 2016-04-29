# frozen_string_literal: true

require 'spec_helper'

class SequencedMutationSpec < PrelaySpec
  mock_schema do
    mutation :AppendToAlbumName do
      type AlbumType

      argument :id, :id
      argument :str, :string

      result_field :album, association: :self

      def mutate(id:, str:)
        album = Prelay::ID.parse(id, schema: self.class.schema).get
        album.update(name: album.name + str)
        {album: album.id}
      end
    end
  end

  it "should run mutations in the passed order" do
    album = Album.first
    id = id_for(album)
    album.update name: 'a'

    execute_query <<-GRAPHQL
      mutation Mutation {
        append_a: append_to_album_name(input: {id: "#{id}", str: "b", clientMutationId: "b"}) {
          clientMutationId,
          album { id, name }
        }
        append_b: append_to_album_name(input: {id: "#{id}", str: "c", clientMutationId: "c"}) {
          clientMutationId,
          album { id, name }
        }
      }
    GRAPHQL

    assert_equal 'abc', album.reload.name

    assert_result \
      'data' => {
        'append_a' => {
          'album' => {
            'id' => id,
            'name' => 'ab',
          },
          'clientMutationId' => 'b',
        },
        'append_b' => {
          'album' => {
            'id' => id,
            'name' => 'abc',
          },
          'clientMutationId' => 'c',
        },
      }
  end
end
