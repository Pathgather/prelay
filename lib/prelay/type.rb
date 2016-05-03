# frozen_string_literal: true

require 'prelay/type/association'
require 'prelay/type/attribute'

module Prelay
  class Type
    extend Subclassable

    attr_reader :record, :associations, :cursor

    def initialize(record, cursor = nil)
      @record = record
      @cursor = cursor
      @associations = {}
    end

    def id
      @record.id
    end

    class << self
      def covered_types
        @covered_types ||= [self].freeze
      end

      def attributes
        @attributes ||= {}
      end

      def associations
        @associations ||= {}
      end

      def attribute(*args)
        define_attribute(Attribute.new(self, *args))
      end

      [:string, :integer, :boolean, :float, :timestamp].each do |datatype|
        define_method(datatype){|name, *args| attribute(name, datatype, *args)}
      end

      [:one_to_one, :one_to_many, :many_to_one].each do |association_type|
        define_method(association_type) do |*args, &block|
          define_association(Association.new(self, association_type, *args, &block))
        end
      end

      def interface(interface)
        interface.covered_types << self
        interfaces << interface

        # Don't let the interface's attributes or associations change once we
        # copy them.
        interface.attributes.freeze
        interface.associations.freeze

        [:attribute, :association].each do |field_type|
          target_fields = interface.send("#{field_type}s")
          target_fields.freeze

          target_fields.each do |name, field|
            copy = field.dup
            copy.send :instance_variable_set, :@parent, self
            send("define_#{field_type}", copy)
          end
        end
      end

      def interfaces
        @interfaces ||= []
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

      def graphql_object
        @graphql_object || raise("GraphQL Object not defined for #{self} (was it included in the schema?)")
      end

      def graphql_object
        @graphql_object ||= begin
          type = self

          object =
            ::GraphQL::ObjectType.define do
              name(type.name.split('::').last.chomp('Type'))
              description(type.description)

              interfaces([type.schema.node_identification.interface] + type.interfaces.map(&:graphql_object))
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

                    argument :types, GraphQL::STRING_TYPE.to_list_type

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

          object.define_connection do
            field :count do
              type GraphQL::INT_TYPE
              resolve -> (obj, args, ctx) { obj.total_count }
            end
          end

          object
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

      def check_interfaces
        interfaces.each do |interface|
          msg = "#{name} claims to implement #{interface.name} but "

          interface.attributes.each do |name, i_attr|
            unless t_attr = attributes[name]
              raise Error, msg + "doesn't have a #{name} attribute"
            end

            unless i_attr.datatype == t_attr.datatype
              raise Error, msg + "#{name} has the wrong datatype"
            end

            unless i_attr.nullable == t_attr.nullable
              raise Error, msg + "#{name} has the wrong nullability"
            end
          end

          interface.associations.each do |name, i_assoc|
            unless t_assoc = associations[name]
              raise Error, msg + "doesn't have a #{name} association"
            end

            unless t_assoc.target_type == i_assoc.target_type
              raise Error, msg + "its #{name} association has a different target_type"
            end

            unless t_assoc.graphql_type == i_assoc.graphql_type
              raise Error, msg + "its #{name} association has a different underlying GraphQL type"
            end

            unless t_assoc.association_type == i_assoc.association_type
              raise Error, msg + "its #{name} association has a different type (#{t_assoc.association_type} instead of #{i_assoc.association_type})"
            end

            t_assoc.target_types.each do |target_type|
              unless i_assoc.target_types.include?(target_type)
                raise Error, msg + "its #{name} association includes a target_type that isn't covered"
              end
            end
          end
        end
      end

      private

      def define_attribute(attribute)
        name = attribute.name
        attributes[name] = attribute
        define_method(name){@record.send(name)}
      end

      def define_association(association)
        name = association.name
        associations[name] = association
        define_method(name) { @associations.fetch(name) { raise "Association #{name} not loaded for #{inspect}" } }
      end
    end
  end
end
