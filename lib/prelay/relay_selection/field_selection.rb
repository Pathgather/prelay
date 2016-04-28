# frozen_string_literal: true

module Prelay
  class RelaySelection
    class FieldSelection < self
      def initialize(selection, type:)
        raise Error, "Expected a GraphQLSelection, got a #{selection.class}" unless selection.is_a?(GraphQLSelection)

        @selections = selection.selections.dup

        # Now that we know the type, figure out if any of the fragments we set
        # aside earlier apply to this selection, and if so, resolve them.
        selection.fragments.each do |fragment_type, selection_sets|
          if fragment_type.covered_types.include?(type)
            selection_sets.each do |selection_set|
              @selections = @selections.merge(selection_set) { |k, o, n| o.merge(n) }
            end
          end
        end

        @selections.dup.each do |key, s|
          name = case s
                 when GraphQLSelection, RelaySelection then s.name
                 when RelayProcessor then s.input.name
                 else raise "Unsupported! #{s.class}"
                 end

          if type.attributes[name]
            # We're cool.
            @selections[key] = FieldSelection.new(s, type: type)
          elsif association = type.associations[name]
            entry_point = association.returns_array? ? :connection : :field
            @selections[key] = RelayProcessor.new(s, target_types: association.target_types, entry_point: entry_point)
          else
            case name
            when :id
              @selections[key] = FieldSelection.new(s, type: type)
            when :clientMutationId, :__typename
              # These are acceptable fields to request, but the GraphQL gem
              # handles them, so we can just ignore them.
              @selections.delete(key)
            else
              raise Error, "unsupported field '#{s.name}'"
            end
          end
        end

        super(
          name: selection.name,
          type: type,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
        )
      end

      def columns
        return @columns unless @columns.nil?
        determine_columns_and_associations
        @columns
      end

      def associations
        return @associations unless @associations.nil?
        determine_columns_and_associations
        @associations
      end

      def count_requested?
        false
      end

      private

      def determine_columns_and_associations
        @columns      = []
        @associations = {}

        fields = {}

        @selections.each do |key, selection|
          name = case selection
                 when RelaySelection then selection.name
                 when RelayProcessor then selection.input.name
                 else raise "Unsupported selection class: #{selection.class}"
                 end

          fields[name] ||= []
          fields[name] << selection
        end

        # id isn't a true attribute, but we'll need it to generate the record's
        # relay id.
        if fields.delete(:id)
          @columns << :id
        end

        @type.attributes.each do |name, attribute|
          # Will need to be a little smarter here if we want to support fields
          # with arguments that need to be pushed down to the DB.
          if fields.delete(name)
            @columns.push *attribute.dependent_columns
          end
        end

        @type.associations.each do |name, association|
          if selections = fields.delete(name)
            selections.each do |selection|
              key = selection.input.aliaz || selection.input.name
              @columns.push *association.local_columns
              associations[key] = [association, selection]
            end
          end
        end

        raise "Unrecognized fields for #{type}: #{fields.inspect}" if fields.any?

        @columns.uniq!
        @columns.freeze
        @associations.freeze
      end
    end
  end
end
