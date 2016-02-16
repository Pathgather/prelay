# frozen_string_literal: true

class RandomAlbumQuery < Prelay::Query
  description <<-DESC

    Returns a random album.

  DESC

  type AlbumType

  resolve -> (obj, args, ctx) {
    ast = Prelay::GraphQLProcessor.new(ctx).ast
    Prelay::RelayProcessor.new(ast, type: AlbumType, entry_point: :field).
      to_resolver.resolve_singular{|ds| ds.order{random{}}.limit(1)}
  }
end

class AlbumsQuery < Prelay::Query
  include Prelay::Connection

  description <<-DESC

    Returns all albums in the DB.

  DESC

  type AlbumType
  order Sequel.desc(:created_at)
end

class ReleasesQuery < Prelay::Query
  include Prelay::Connection

  description <<-DESC

    Returns all releases in the DB.

  DESC

  type ReleaseInterface
  order Sequel.desc(:created_at)
end
