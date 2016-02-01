# frozen_string_literal: true

module Prelay
  class Mutation
    class ResultField
      attr_reader :name, :normalized_name, :association

      def initialize(klass, name, association: nil, edge: false, graphql_type: nil)
        @klass  = klass
        @name   = name
        @edge   = edge
        @association = association.freeze
        @normalized_name = name.to_s.chomp('_edge').to_sym
        @graphql_type = graphql_type
      end

      def graphql_type
        if @graphql_type
          @graphql_type
        elsif @association
          type = target_type.graphql_object
          edge? ? type.edge_type : type
        elsif @name == :id
          GraphQL::ID_TYPE
        else
          raise "Have not handled graphql_type for #{@klass}##{@name}"
        end
      end

      def edge?
        @edge
      end

      def target_type
        type = @klass.type

        if @association.nil? || @association == :self
          type
        else
          get_associated_type(type: type, association: @association)
        end
      end

      private

      def get_associated_type(type:, association:)
        case association
        when Symbol
          type.associations.fetch(association){raise "#{@klass} referenced an association '#{association}' on type #{type}, but it doesn't exist!"}.target_type
        when Array
          association.inject(type) { |t, a| get_associated_type(type: t, association: a) }
        else
          raise "Unsupported result field association declaration!: #{association.inspect}"
        end
      end
    end
  end
end
