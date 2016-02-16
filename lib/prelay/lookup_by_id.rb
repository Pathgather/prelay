# frozen_string_literal: true

module Prelay
  module LookupById
    attr_reader :object

    def self.included(base)
      base.argument :id, :id
      base.prepend PrependedMethods
    end

    module PrependedMethods
      def mutate(id:, **args)
        @object = ID.parse(id, expected_type: self.class.type).get

        if @object.nil?
          # Return the values that are necessary for the GraphQL gem to work,
          # but let them all be nil.
          r = {}
          self.class.result_fields.each_value do |result_field|
            r[result_field.normalized_name] = nil
          end
          r
        else
          super(**args)
        end
      end
    end
  end
end
