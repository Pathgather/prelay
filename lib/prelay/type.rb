# frozen-string-literal: true

require 'prelay/type/association'
require 'prelay/type/attribute'

module Prelay
  class Type
    BY_MODEL = {}
    BY_NAME  = {}

    attr_reader :record, :associations

    def initialize(record)
      @record = record
      @associations = {}
    end

    def id
      @record.id
    end

    class << self
      def inherited(subclass)
        super
        BY_NAME[subclass.to_s.split('::').last.chomp('Type')] = subclass
      end

      def attributes
        @attributes ||= {}
      end

      def associations
        @associations ||= {}
      end

      def attribute(*args)
        attribute = Attribute.new(self, *args)
        name = attribute.name
        attributes[name] = attribute
        define_method(name){@record.send(name)}
      end

      def association(*args)
        association = Association.new(self, *args)
        name = association.name
        associations[name] = association
        define_method(name) { @associations.fetch(name) { raise "Association #{name} not loaded for #{inspect}" } }
      end

      def graphql_object
        @graphql_object || raise("GraphQL Object not defined for #{self} (was it included in the schema?)")
      end

      def define_graphql_object(node_identification)
        type = self

        @graphql_object = ::GraphQL::ObjectType.define do
          name(type.name.split('::').last.chomp('Type'))
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
                resolve -> (obj, args, ctx) {
                  node = ctx.ast_node
                  key = (node.alias || node.name).to_sym
                  obj.associations.fetch(key) { raise "Association #{key} not loaded for #{obj.inspect}" }
                }
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
