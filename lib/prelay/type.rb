# frozen_string_literal: true

require 'prelay/type/association'
require 'prelay/type/attribute'

module Prelay
  class Type
    extend Subclassable

    attr_reader :record, :associations

    def initialize(record)
      @record = record
      @associations = {}
    end

    def id
      @record.id
    end

    class << self
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

      [:string, :integer, :boolean, :float].each do |datatype|
        define_method(datatype){|name, *args| attribute(name, datatype, *args)}
      end

      def interface(interface, foreign_key)
        interface.types << self
        interfaces[interface] = foreign_key
      end

      def interfaces
        @interfaces ||= {}
      end

      def filter(name, type = :boolean, &block)
        filters[name] = [type, block]
      end

      def filters
        @filters ||= {}
      end

      def dataset_scope(&block)
        if block_given?
          @dataset_scope = block
        else
          @dataset_scope
        end
      end

      def additional_models(*models)
        models.each { |model| associate_with_model(model) }
      end

      def associate_with_model(model)
        associated_models << model
      end

      def associated_models
        @associated_models ||= []
      end

      [:one_to_one, :one_to_many, :many_to_one].each do |association_type|
        define_method(association_type) do |*args|
          association = Association.new(self, association_type, *args)
          name = association.name
          associations[name] = association
          define_method(name) { @associations.fetch(name) { raise "Association #{name} not loaded for #{inspect}" } }
        end
      end

      def graphql_object
        @graphql_object || raise("GraphQL Object not defined for #{self} (was it included in the schema?)")
      end

      def graphql_object
        @graphql_object ||= begin
          type = self

          ::GraphQL::ObjectType.define do
            name(type.name.split('::').last.chomp('Type'))
            description(type.description)

            interfaces([type.schema.node_identification.interface] + type.interfaces.keys.map(&:graphql_object))
            global_id_field :id

            type.attributes.each_value do |attribute|
              field attribute.name do
                description(attribute.description)
                type(attribute.graphql_type)
              end
            end

            type.associations.each_value do |association|
              if association.returns_array?
                connection association.name do
                  type -> { association.graphql_type.connection_type }
                  description(association.description)

                  association.target_type.filters.each do |name, (type, _)|
                    argument name, Query::Argument.new(nil, name, type).graphql_type
                  end

                  resolve -> (obj, args, ctx) {
                    node = ctx.ast_node
                    key = (node.alias || node.name).to_sym
                    obj.associations.fetch(key) { raise "Association #{key} not loaded for #{obj.inspect}" }
                  }
                end
              else
                field association.name do
                  description(association.description)
                  type -> {
                    t = association.graphql_type
                    association.nullable ? t : t.to_non_null_type
                  }
                end
              end
            end
          end
        end
      end

      def description(d = nil)
        d ? @description = d : @description
      end

      def order(o = nil)
        o ? @order = o : @order
      end

      def model(m = nil)
        if m
          @model = m
          associate_with_model(m)
        else
          @model
        end
      end

      def name(n = nil)
        if n
          @name = n
        else
          @name ||= super().split('::').last.chomp('Type')
        end
      end
    end
  end
end
