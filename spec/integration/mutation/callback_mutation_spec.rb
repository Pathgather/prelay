# frozen_string_literal: true

require 'spec_helper'

class CallbackMutationSpec < PrelaySpec
  let(:album) { Album.first! }

  mock_schema do
    mutation :CallbackSpec do
      type AlbumType

      argument :id, :id
      argument :name, :string

      result_field :album, association: :self

      def before_mutate
        $callback_mutation_spec << 'before'
      end

      def mutate(id:, name:)
        $callback_mutation_spec << 'during'

        album = Prelay::ID.parse(id, schema: self.class.schema).get
        album.update(name: name)
        {album: album.id}
      end

      def after_mutate
        $callback_mutation_spec << 'after'
      end
    end
  end

  it "should support callbacks on a mutation" do
    $callback_mutation_spec = []
    @input = {
      id: id_for(album),
      name: "New Album Name"
    }

    execute_mutation :callback_spec, graphql: <<-GRAPHQL
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
    assert_equal ['before', 'during', 'after'], $callback_mutation_spec

    assert_mutation_result \
      'album' => {
        'id' => id_for(album),
        'name' => "New Album Name"
      }
  end
end
