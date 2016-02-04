# frozen_string_literal: true

module Prelay
  class Type
    class Association
      attr_reader :parent, :name, :sequel_association, :sequel_association_name, :description, :nullable, :order

      def initialize(parent, association_type, name, description, target: nil, sequel_association_name: nil, target_types: nil, nullable: nil, order: nil, foreign_key: nil)
        @parent                  = parent
        @name                    = name
        @description             = description
        @nullable                = nullable
        @association_type        = association_type
        @order                   = order
        @sequel_association_name = sequel_association_name || name
        @foreign_key             = foreign_key

        if target
          @specified_target       = target
          @specified_target_types = target_types
        elsif parent < Type
          @sequel_association = parent.model.association_reflections.fetch(@sequel_association_name) do
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

      def derived_order
        return @order if @order

        if @sequel_association
          if o = @sequel_association[:order]
            return o
          end

          associated_class = @sequel_association.associated_class
          return Sequel.qualify(associated_class.table_name, associated_class.primary_key)
        end

        :id
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

      def local_columns
        a = sequel_association

        case @association_type
        when :many_to_one
          if a
            [a.fetch(:key)]
          else
            # TODO: Fix.
            target_types.map{|t| t.interfaces.fetch(target_type)}.uniq
          end
        when :one_to_many, :one_to_one
          if a
            [a.primary_key]
          else
            [:id]
          end
        else
          raise "Unsupported type: #{type}"
        end
      end

      def remote_columns
        a = sequel_association

        case @association_type
        when :many_to_one
          if a
            [a.primary_key]
          else
            # TODO: Fix.
            [:id]
          end
        when :one_to_many, :one_to_one
          if a
            [a.fetch(:key)]
          else
            return [@foreign_key] if @foreign_key
            raise "Can't determine foreign key for association: #{inspect}"
          end
        else
          raise "Unsupported type: #{type}"
        end
      end
    end
  end
end
