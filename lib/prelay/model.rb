# frozen-string-literal: true

require 'prelay/model/association'
require 'prelay/model/attribute'

module Prelay
  class Model
    BY_SEQUEL_MODEL = {}

    class << self
      def attributes
        @attributes ||= {}
      end

      def associations
        @associations ||= {}
      end

      def attribute(*args)
        attribute = Attribute.new(self, *args)
        attributes[attribute.name] = attribute
      end

      def association(*args)
        association = Association.new(self, *args)
        associations[association.name] = association
      end

      def graphql_object
        model = self

        ::GraphQL::ObjectType.define do
          name(model.name.split('::').last)
          description(model.description)

          model.attributes.each_value do |attribute|
            field attribute.name, attribute.graphql_type
          end

          model.associations.each_value do |association|
            if association.returns_array?
              connection association.name do
                type -> { association.graphql_type.connection_type }
              end
            else
              field association.name do
                type -> { association.graphql_type }
              end
            end
          end
        end
      end

      def description(d = nil)
        d ? @description = d : @description
      end

      def model(m = nil)
        if m
          @model = m
          BY_SEQUEL_MODEL[m] = self
        else
          @model
        end
      end
    end
  end
end
