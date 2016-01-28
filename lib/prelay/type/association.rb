# frozen_string_literal: true

module Prelay
  class Type
    class Association
      attr_reader :name, :sequel_association, :description, :nullable

      def initialize(type, association_type, name, description, nullable: nil)
        @type        = type
        @name        = name
        @description = description
        @nullable    = nullable

        @sequel_association = @type.model.association_reflections.fetch(name) do
          raise "Could not find an association '#{name}' on the Sequel model #{@type.model}"
        end

        unless @sequel_association[:type] == association_type
          raise "Association #{name} on #{type} declared as #{association_type}, but the underlying Sequel association is #{@sequel_association[:type]}"
        end

        case association_type
        when :one_to_many              then raise "Specified a #{association_type} association (#{type}##{name}) with a :nullable option, which is not allowed" unless nullable.nil?
        when :many_to_one, :one_to_one then raise "Specified a #{association_type} association (#{type}##{name}) without a :nullable option, which is required" if nullable.nil?
        else raise "Unsupported association type: #{association_type}"
        end
      end

      def model
        @type.model
      end

      def target_type
        Type::BY_MODEL.fetch(sequel_association.associated_class) do
          raise "Could not find a Prelay::Type for #{sequel_association.associated_class}"
        end
      end

      def returns_array?
        sequel_association.returns_array?
      end

      def graphql_type
        target_type.graphql_object
      end

      def local_column
        case t = sequel_association.fetch(:type)
        when :many_to_one              then sequel_association.fetch(:key)
        when :one_to_many, :one_to_one then sequel_association.primary_key
        else raise "Unsupported Sequel association type: #{t.inspect}"
        end
      end

      def remote_column
        case t = sequel_association.fetch(:type)
        when :many_to_one              then sequel_association.primary_key
        when :one_to_many, :one_to_one then sequel_association.fetch(:key)
        else raise "Unsupported Sequel association type: #{t.inspect}"
        end
      end
    end
  end
end
