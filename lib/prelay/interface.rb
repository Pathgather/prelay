# frozen_string_literal: true

module Prelay
  class Interface
    class << self
      def inherited(subclass)
        super
        Type::BY_NAME[subclass.to_s.split('::').last.chomp('Interface')] = subclass
      end

      # Eval is evil, but use it to define some fast class accessors:
      [:description].each { |m| eval "def #{m}(arg = nil); arg ? @#{m} = arg : @#{m}; end" }

      def attributes
        @attributes ||= {}
      end

      def associations
        @associations ||= {}
      end

      def attribute(*args)
        attributes[args.first] = Type::Attribute.new(self, *args)
      end

      [:one_to_one, :one_to_many, :many_to_one].each do |association_type|
        define_method(association_type) do |*args|
          associations[args.first] = Type::Association.new(self, association_type, *args)
        end
      end

      def types
        @types ||= []
      end

      attr_reader :graphql_object

      def define_graphql_object(node_identification)
        interface = self

        @graphql_object = ::GraphQL::InterfaceType.define do
          name(interface.name.split('::').last.chomp('Interface'))
          description(interface.description)

          id_field = GraphQL::Relay::GlobalIdField.new(nil)
          id_field.resolve = -> (obj, args, ctx) {
            # It's necessary to include an id field on the interface, so that
            # queries can request it, but the actual calculation of the id
            # will fall to the Node interface, so this should never be called.
            raise "Shouldn't get here! If we do we want to test it better!"
          }
          field :id, field: id_field

          resolve_type -> (object) {
            Type::BY_MODEL.fetch(object.record.class){|k| raise "No Prelay::Type found for class #{k}"}.graphql_object
          }

          interface.attributes.each_value do |attribute|
            field attribute.name do
              description(attribute.description)
              type(attribute.graphql_type)
            end
          end

          interface.associations.each_value do |association|
            if association.returns_array?
              connection association.name do
                type -> { association.graphql_type.connection_type }
                description(association.description)
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
  end
end
