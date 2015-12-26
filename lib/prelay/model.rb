# frozen-string-literal: true

require 'prelay/model/association'
require 'prelay/model/attribute'

module Prelay
  class Model
    class << self
      def attributes
        @attributes ||= {}
      end

      def associations
        @associations ||= {}
      end

      def attribute(*args)
        attribute = Attribute.new(*args)
        attributes[attribute.name] = attribute
      end

      def association(*args)
        association = Association.new(*args)
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
        end
      end

      def description(d = nil)
        d ? @description = d : @description
      end
    end
  end
end
