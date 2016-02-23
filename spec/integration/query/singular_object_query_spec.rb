# frozen_string_literal: true

require 'spec_helper'

class SingularObjectQuerySpec < PrelaySpec
  let :schema do
    Prelay::Schema.new(temporary: true)
  end

  let :artist_type do
    mock :type, schema: schema do
      name "Artist"
      model Artist
      attribute :first_name, "The first name of the artist", datatype: :string
    end
  end

  let :album_type do
    mock :type, schema: schema do
      name "Album"
      model Album
      attribute :name, "The name of the album", datatype: :string

      many_to_one :artist, "The artist who released the album", nullable: false
    end
  end

  let :query do
    artist_type
    t = album_type
    mock :query, schema: schema do
      name "RandomAlbumQuery"
      description "Returns a random album."
      type AlbumType
      resolve -> (obj, args, ctx) {
        ast = Prelay::GraphQLProcessor.new(ctx).ast
        Prelay::RelayProcessor.new(ast, type: AlbumType, entry_point: :field).
          to_resolver.resolve_singular{|ds| ds.order{random{}}.limit(1)}
      }
    end
  end

  it "should support returning a singular object" do
    query
    execute_query <<-GRAPHQL
      query Query {
        random_album {
          id,
          name,
          artist {
            id,
            first_name
          }
        }
      }
    GRAPHQL

    pk = Base64.decode64(@result['data']['random_album']['id']).split(':').last
    album = Album[pk]

    assert_sqls [
      %(SELECT "albums"."id", "albums"."name", "albums"."artist_id" FROM "albums" ORDER BY random() LIMIT 1),
      %(SELECT "artists"."id", "artists"."first_name" FROM "artists" WHERE ("artists"."id" IN ('#{album.artist.id}')) ORDER BY "artists"."id"),
    ]

    assert_result \
      'data' => {
        'random_album' => {
          'id' => id_for(album),
          'name' => album.name,
          'artist' => {
            'id' => id_for(album.artist),
            'first_name' => album.artist.first_name
          }
        }
      }
  end
end
