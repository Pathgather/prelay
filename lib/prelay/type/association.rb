# frozen_string_literal: true

module Prelay
  class Type
    class Association
      attr_reader :parent, :name, :sequel_association, :sequel_association_name, :description, :nullable, :order, :association_type, :local_column, :remote_column, :dataset_block

      def initialize(parent, association_type, name, description = nil, target: nil, sequel_association_name: nil, target_types: nil, nullable: nil, order: nil, local_column: nil, remote_column: nil, dataset_block: nil)
        @parent                  = parent
        @name                    = name
        @description             = description
        @nullable                = nullable
        @association_type        = association_type
        @order                   = order
        @sequel_association_name = sequel_association_name || name
        @dataset_block           = dataset_block

        if target
          @specified_target       = target
          @specified_target_types = target_types
        elsif parent < Type
          @sequel_association = parent.model.association_reflections.fetch(@sequel_association_name) do
            raise "Could not find an association '#{name}' on the Sequel model #{parent.model} while configuring association #{name} on #{@parent}"
          end

          unless @sequel_association[:type] == association_type
            raise "Association #{name} on #{parent.name} declared as #{association_type}, but the underlying Sequel association is #{@sequel_association[:type]}"
          end
        else
          raise "Can't configure association #{name} on #{parent.name}"
        end

        @local_column  = local_column
        @remote_column = remote_column

        if a = sequel_association
          case @association_type
          when :many_to_one
            @local_column  ||= a.fetch(:key)
            @remote_column ||= a.primary_key
          when :one_to_many, :one_to_one
            @local_column  ||= a.primary_key
            @remote_column ||= a.fetch(:key)
          else
            raise Error, "Unsupported association type: #{association_type}"
          end
        end

        error_msg = "Specified a #{association_type} association (#{parent}##{name})"

        case association_type
        when :one_to_many
          raise "#{error_msg} with a :nullable option, which is not allowed" unless nullable.nil?
          raise "#{error_msg} without an :order option, which is not allowed" if order.nil?
        when :many_to_one, :one_to_one
          raise "#{error_msg} without a :nullable option, which is required" if nullable.nil?
          raise "#{error_msg} with an :order option, which is not allowed" unless order.nil?
        else
          raise Error, "Unsupported association type: #{association_type}"
        end

        case @association_type
        when :many_to_one              then @remote_column ||= :id
        when :one_to_many, :one_to_one then @local_column  ||= :id
        else raise Error, "Unsupported association type: #{association_type}"
        end

        raise Error, "Can't determine local_column for association #{name} on #{parent.name}"  unless @local_column
        raise Error, "Can't determine remote_column for association #{name} on #{parent.name}" unless @remote_column
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
          if t = @specified_target
            if t.is_a?(Class) && (t < Type || t < Interface)
              t
            else
              begin
                Kernel.const_get(@specified_target.to_s)
              rescue
                raise Error, "could not load constant #{@specified_target.inspect} while configuring association #{@name} on #{@parent}"
              end
            end
          elsif parent < Type
            begin
              target_class = sequel_association.associated_class
            rescue NameError
              raise Error, "could not load constant #{sequel_association[:class_name]} while configuring association #{@name} on #{@parent}"
            end
            parent.schema.type_for_model!(target_class)
          end
        )
      end

      def target_types
        @target_types ||= (
          if @specified_target_types
            @specified_target_types.map do |t|
              if t.is_a?(Class) && t < Type
                t
              elsif t.is_a?(Symbol) || t.is_a?(String)
                Kernel.const_get(t.to_s)
              else
                raise Error, "unsupported target type: #{t.inspect}"
              end
            end
          else
            target_type.covered_types
          end
        ).freeze
      end

      def returns_array?
        @association_type == :one_to_many
      end

      def graphql_type
        target_type.graphql_object
      end
    end
  end
end
