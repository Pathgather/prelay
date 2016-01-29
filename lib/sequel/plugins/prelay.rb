# frozen_string_literal: true

module Sequel
  module Plugins
    module Prelay
      module InstanceMethods
        def prelay_id
          ::Prelay::ID.for(self)
        end
      end
    end
  end
end
