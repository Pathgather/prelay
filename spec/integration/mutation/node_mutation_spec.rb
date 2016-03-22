# frozen_string_literal: true

require 'spec_helper'

class NodeMutationSpec < PrelaySpec
  let(:album) { Album.first! }

  mock_schema do
    mutation :UpdateAlbumName do
      type AlbumType

      argument :id, :id
      argument :name, :string

      result_field :album, association: :self

      def mutate(id:, name:)
        album = Prelay::ID.parse(id, schema: self.class.schema).get
        album.update(name: name)
        {album: album.id}
      end
    end
  end

  it "should support invoking a mutation that returns a node" do
    @input = {
      id: id_for(album),
      name: "New Album Name"
    }

    execute_mutation :update_album_name, graphql: <<-GRAPHQL
      album {
        id,
        name
      }
    GRAPHQL

    assert_sqls [
      %(SELECT * FROM "albums" WHERE "id" = '#{album.id}'),
      %(SAVEPOINT autopoint_1),
      %(UPDATE "albums" SET "name" = 'New Album Name' WHERE ("id" = '#{album.id}')),
      %(RELEASE SAVEPOINT autopoint_1),
      %(SELECT "albums"."id", "albums"."name" FROM "albums" WHERE ("id" = '#{album.id}') ORDER BY "created_at" DESC),
    ]

    assert_equal "New Album Name", album.reload.name

    assert_mutation_result \
      'album' => {
        'id' => id_for(album),
        'name' => "New Album Name"
      }
  end

  it "should support fuzzed queries provided alongside mutations"
end
