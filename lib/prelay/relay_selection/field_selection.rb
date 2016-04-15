# frozen_string_literal: true

module Prelay
  class RelaySelection
    class FieldSelection < self
      def initialize(selection, target_types:)
        selections_by_type = {}
        target_types.each {|t| selections_by_type[t] = selection.selections.dup}

        # Now that we know the type, figure out if any of the fragments we set
        # aside earlier apply to this selection, and if so, resolve them.
        selection.fragments.each do |type, selection_sets|
          type.covered_types.each do |t|
            next unless selections_by_type[t]

            selection_sets.each do |selection_set|
              selections_by_type[t] = selections_by_type[t].merge(selection_set) { |k, o, n| o.merge(n) }
            end
          end
        end

        selections_by_type.each do |type, selection_set|
          selection_set.each do |key, s|
            if type.attributes[s.name]
              # We're cool.
              selection_set[key] = FieldSelection.new(s, target_types: target_types)
            elsif association = type.associations[s.name]
              klass = association.returns_array? ? ConnectionSelection : FieldSelection
              selection_set[key] = klass.new(s, target_types: association.target_types)
            else
              case s.name
              when :id
                selection_set[key] = FieldSelection.new(s, target_types: target_types)
              when :clientMutationId, :__typename
                # These are acceptable fields to request, but the GraphQL gem
                # handles them, so we can just ignore them.
                selection_set.delete(key)
              else
                raise Error, "unsupported field '#{s.name}'"
              end
            end
          end
        end

        super(
          name: selection.name,
          types: target_types,
          aliaz: selection.aliaz,
          arguments: selection.arguments,
          selections: selections_by_type,
          fragments: selection.fragments,
          metadata: {},
        )
      end
    end
  end
end
