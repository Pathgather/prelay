# frozen-string-literal: true

module Prelay
  class Model
    class Association
      attr_reader :name

      def initialize(name)
        @name = name
      end
    end
  end
end
