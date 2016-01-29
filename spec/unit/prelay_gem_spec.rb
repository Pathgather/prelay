# frozen_string_literal: true

require 'spec_helper'

class PrelayGemSpec < PrelaySpec
  # Silly spec, but make sure our frozen string literal magic comments are
  # being taken seriously :)
  it "should have a frozen version number" do
    assert_instance_of String, ::Prelay::VERSION
    assert ::Prelay::VERSION.frozen?
  end
end
