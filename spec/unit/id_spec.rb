# frozen_string_literal: true

require 'spec_helper'

class IDSpec < PrelaySpec
  let :album do
    album = Album.new
    album.id = "89565d7e-5fe8-4a66-be2c-3fcdaac3a721"
    album
  end

  let :id do
    "QWxidW06ODk1NjVkN2UtNWZlOC00YTY2LWJlMmMtM2ZjZGFhYzNhNzIx"
  end

  it "should encode types and pks correctly" do
    type   = 'Album'
    pk     = "89565d7e-5fe8-4a66-be2c-3fcdaac3a721"
    actual = Prelay::ID.encode(type: type, pk: pk)

    assert_equal Base64.strict_encode64("#{type}:#{pk}"), actual
    assert_equal id, actual
  end

  it "should parse ids correctly" do
    parsed = Prelay::ID.parse(id)

    assert_equal "89565d7e-5fe8-4a66-be2c-3fcdaac3a721", parsed.pk
    assert_equal AlbumType, parsed.type
  end

  it "should support expected types when parsing ids" do
    error = assert_raises(Prelay::Error) { Prelay::ID.parse(id, expected_type: ArtistType) }

    assert_equal error.message, "Expected object id for a Artist, got one for a Album"
  end

  it "should support returning the encoded id for a record" do
    assert_equal id, Prelay::ID.for(album)
  end

  it "should support fetching the referenced record directly" do
    a1 = Album.first
    a2 = Prelay::ID.get(Prelay::ID.for(a1))
    assert_equal a1, a2
  end

  it ".get should not raise an error when getting a record that doesn't exist" do
    assert_nil Prelay::ID.get(id)
  end

  it ".get! should raise an error when getting a record that doesn't exist" do
    assert_raises(Sequel::NoMatchingRow) { Prelay::ID.get!(id) }
  end
end
