# frozen-string-literal: true

module Prelay
  class Model
    class Association
      attr_reader :name

      def initialize(model, name)
        @model = model
        @name  = name
      end

      def sequel_model
        @model.model
      end

      def sequel_association
        m = sequel_model
        m.association_reflections.fetch(name) do
          raise "Could not find an association '#{name}' on the Sequel model #{m}"
        end
      end

      def target_model
        Prelay::Model::BY_SEQUEL_MODEL.fetch(sequel_association.associated_class) do
          raise "Could not find a Prelay::Model for #{sequel_association.associated_class}"
        end
      end

      def returns_array?
        sequel_association.returns_array?
      end

      def graphql_type
        target_model.graphql_object
      end

      def dependent_columns
        # What column(s) do we need to load on the local record to associate
        # other records with it correctly?

        @dependent_columns ||= begin
          case sequel_association.fetch(:type)
          when :many_to_one              then [sequel_association[:key]].freeze
          when :one_to_many, :one_to_one then [sequel_association[:primary_key]].freeze
          else raise "Haven't handled dependent_columns for association type: #{sequel_association_type.inspect}"
          end
        end
      end
    end
  end
end
