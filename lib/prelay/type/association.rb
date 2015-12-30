# frozen-string-literal: true

module Prelay
  class Type
    class Association
      attr_reader :name

      def initialize(type, name)
        @type = type
        @name = name
      end

      def model
        @type.model
      end

      def sequel_association
        m = model
        m.association_reflections.fetch(name) do
          raise "Could not find an association '#{name}' on the Sequel model #{m}"
        end
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
