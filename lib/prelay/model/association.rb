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
        sequel_model.association_reflections[name]
      end

      def returns_array?
        sequel_association.returns_array?
      end

      def graphql_type
        Prelay::Model::BY_SEQUEL_MODEL[sequel_association.associated_class].graphql_object
      end
    end
  end
end
