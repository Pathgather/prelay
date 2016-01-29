# frozen_string_literal: true

require 'spec_helper'

class SequelPluginSpec < PrelaySpec
  Sequel::Model.plugin :prelay

  let :album do
    album = Album.new
    album.id = "89565d7e-5fe8-4a66-be2c-3fcdaac3a721"
    album
  end

  let :id do
    "QWxidW06ODk1NjVkN2UtNWZlOC00YTY2LWJlMmMtM2ZjZGFhYzNhNzIx"
  end

  it "should provide a prelay_id instance method" do
    assert_equal id, album.prelay_id
  end

  it "should raise a helpful error when the given model doesn't have an associated type" do
    class PrelaySequelPluginTestModel < Sequel::Model(DB[:artists].select(:id))
      set_primary_key :id
    end

    instance = PrelaySequelPluginTestModel.new
    instance.id = "89565d7e-5fe8-4a66-be2c-3fcdaac3a721"

    error = assert_raises(RuntimeError) { instance.prelay_id }
    assert_equal "Could not find a Prelay::Type subclass corresponding to the SequelPluginSpec::PrelaySequelPluginTestModel model", error.message
  end
end
