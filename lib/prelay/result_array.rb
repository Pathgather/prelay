# frozen_string_literal: true

module Prelay
  class ResultArray < DelegateClass(Array)
    attr_accessor :count
  end
end
