# frozen_string_literal: true

module Prelay
  class Type
    class Association
      attr_reader :parent, :name, :sequel_association, :description, :nullable

      def initialize(parent, association_type, name, description, target: nil, target_types: nil, nullable: nil)
        @parent           = parent
        @name             = name
        @description      = description
        @nullable         = nullable
        @association_type = association_type

        if target
          @specified_target       = target
          @specified_target_types = target_types
        elsif parent < Type
          @sequel_association = parent.model.association_reflections.fetch(name) do
            raise "Could not find an association '#{name}' on the Sequel model #{parent.model}"
          end

          unless @sequel_association[:type] == association_type
            raise "Association #{name} on #{parent} declared as #{association_type}, but the underlying Sequel association is #{@sequel_association[:type]}"
          end
        else
          raise "Can't configure association #{name} on #{parent}"
        end

        case association_type
        when :one_to_many              then raise "Specified a #{association_type} association (#{parent}##{name}) with a :nullable option, which is not allowed" unless nullable.nil?
        when :many_to_one, :one_to_one then raise "Specified a #{association_type} association (#{parent}##{name}) without a :nullable option, which is required" if nullable.nil?
        else raise "Unsupported association type: #{association_type}"
        end
      end

      def model
        @parent.model
      end

      def target_type
        @target_type ||= (
          if @specified_target
            Kernel.const_get(@specified_target.to_s)
          elsif parent < Type
            target_class = sequel_association.associated_class
            Type::BY_MODEL.fetch(target_class) { raise "Could not find a Prelay::Type for #{target_class}" }
          end
        )
      end

      def target_types
        @target_types ||= (
          if target_type < Interface
            if @specified_target_types
              @specified_target_types.map { |l| Kernel.const_get(l.to_s) }
            else
              target_type.types
            end
          elsif target_type < Type
            [target_type]
          else
            raise "Unsupported parent class for #{self.class}: #{target_type}"
          end
        ).freeze
      end

      def returns_array?
        @association_type == :one_to_many
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
