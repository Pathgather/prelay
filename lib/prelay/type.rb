# frozen-string-literal: true

require 'prelay/type/association'
require 'prelay/type/attribute'

module Prelay
  class Type
    BY_MODEL = {}
    BY_NAME  = {}

    class << self
      def inherited(subclass)
        super
        BY_NAME[subclass.to_s.split('::').last] = subclass
      end

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
        @graphql_object || raise("GraphQL Object not defined for #{self} (was it included in the schema?)")
      end

      def define_graphql_object(node_identification)
        type = self

        @graphql_object = ::GraphQL::ObjectType.define do
          name(type.name.split('::').last)
          description(type.description)

          interfaces [node_identification.interface]
          global_id_field :id

          type.attributes.each_value do |attribute|
            field attribute.name, attribute.graphql_type
          end

          type.associations.each_value do |association|
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
          BY_MODEL[m] = self
        else
          @model
        end
      end
    end
  end
end