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

  describe "#prelay_id" do
    it "should return the object's encoded id" do
      assert_equal id, album.prelay_id
    end

    it "should raise a helpful error when the given model doesn't have an associated type" do
      class PrelaySequelPluginTestModel < Sequel::Model(DB[:artists].select(:id))
        set_primary_key :id
      end

      instance = PrelaySequelPluginTestModel.new
      instance.id = "89565d7e-5fe8-4a66-be2c-3fcdaac3a721"

      error = assert_raises(Prelay::Error) { instance.prelay_id }
      assert_equal "Type not found for model: SequelPluginSpec::PrelaySequelPluginTestModel", error.message
    end

    it "should raise a helpful error when the given model doesn't have a pk yet"

    it "should accept a 'schema' argument for when the desired schema isn't the primary one"

    it "should also work for integer ids"
  end
end
