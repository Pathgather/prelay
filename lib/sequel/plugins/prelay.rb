# frozen_string_literal: true

module Sequel
  module Plugins
    module Prelay
      module InstanceMethods
        def prelay_id(schema: ::Prelay.primary_schema)
          ::Prelay::ID.for(self, schema: schema)
        end
      end
    end
  end
end
