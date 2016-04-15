# frozen_string_literal: true

module Prelay
  class ResultArray < DelegateClass(Array)
    attr_writer :total_count

    def total_count
      @total_count || 0
    end
  end
end
