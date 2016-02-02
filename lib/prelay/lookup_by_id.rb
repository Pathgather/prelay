# frozen_string_literal: true

module Prelay
  module LookupById
    def self.included(base)
      base.argument :id, :id
      base.prepend PrependedMethods
    end

    attr_reader :relay_id

    module PrependedMethods
      def mutate(id:, **args)
        @relay_id = ID.parse(id, expected_type: self.class.type)
        super(**args)
      end

      def object
        # This loads all fields from the DB, but that's ok, since
        # validations/callbacks could touch any column anyway.
        @object ||= @relay_id.get
      end
    end
  end
end
