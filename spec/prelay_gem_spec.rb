require 'spec_helper'

class PrelayGemSpec < PrelaySpec
  it "should have a frozen version number" do
    assert_instance_of String, ::Prelay::VERSION
    assert ::Prelay::VERSION.frozen?
  end
end
