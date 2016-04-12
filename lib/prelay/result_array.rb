# frozen_string_literal: true

module Prelay
  class ResultArray < DelegateClass(Array)
    attr_writer :count

    def count
      @count || 0
    end
  end
end
