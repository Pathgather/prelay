# frozen_string_literal: true

module Prelay
  class RelayProcessor
    attr_reader :ast, :target_types

    # The calling code should know if the field being passed in is a Relay
    # connection or edge call, so it must provide an :entry_point argument to
    # tell us how to start parsing.
    def initialize(input, target_types:, entry_point:)
      @target_types = target_types.map { |type| types_for_type(type) }.flatten.uniq

      @ast =
        case entry_point
        when :field      then process_field(input)
        when :connection then process_connection(input)
        when :edge       then process_edge(input)
        else raise Error, "Unsupported entry_point: #{entry_point}"
        end
    end

    def to_resolver
      DatasetResolver.new(ast: @ast)
    end

    private

    def process_connection(selection)
      metadata = {}

      selections =
        if edges = selection.selections[:edges]
          # It's against the Relay spec to request edges on connections
          # without either a 'first' or 'last' argument, but since the gem
          # doesn't stop it from happening, throw an error when/if that
          # happens, just to be safe. If we want to support that at some point
          # (allowing the client to load all records in a connection) we
          # could, but that behavior should be thought through, and a limit
          # should probably still be applied to prevent abuse.
          unless selection.arguments[:first] || selection.arguments[:last]
            raise Error, "Tried to access the connection '#{selection.name}' without a 'first' or 'last' argument."
          end
          process_edge(edges).selections
        else
          {}
        end

      if page_info = selection.selections[:pageInfo]
        metadata[:has_next_page]     = true if page_info.selections[:hasNextPage]
        metadata[:has_previous_page] = true if page_info.selections[:hasPreviousPage]

        target_types.each do |type|
          (selections[type] ||= {})[:id] ||= RelaySelection.new(name: :id, types: [type])
        end
      end

      if selection.selections[:count]
        metadata[:count_requested] = true
      end

      RelaySelection.new(
        name: selection.name,
        types: target_types,
        aliaz: selection.aliaz,
        arguments: selection.arguments,
        selections: selections,
        fragments: selection.fragments,
        metadata: metadata,
      )
    end

    def process_edge(selection)
      selections =
        if node = selection.selections[:node]
          process_field(node).selections
        else
          {}
        end

      if selection.selections[:cursor]
        target_types.each do |type|
          (selections[type] ||= {})[:cursor] ||= RelaySelection.new(name: :cursor, types: [type])
        end
      end

      RelaySelection.new(
        name: selection.name,
        types: target_types,
        aliaz: selection.aliaz,
        arguments: selection.arguments,
        selections: selections,
        fragments: selection.fragments,
        metadata: {},
      )
    end

    def process_field(selection)
      selections_by_type = {}
      target_types.each {|t| selections_by_type[t] = selection.selections.dup}

      # Now that we know the type, figure out if any of the fragments we set
      # aside earlier apply to this selection, and if so, resolve them.
      selection.fragments.each do |type, selection_sets|
        types_for_type(type).each do |t|
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
            selection_set[key] = process_field(s)
          elsif association = type.associations[s.name]
            entry_point = association.returns_array? ? :connection : :field
            selection_set[key] = self.class.new(s, target_types: association.target_types, entry_point: entry_point).ast
          else
            case s.name
            when :id
              selection_set[key] = process_field(s)
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

      RelaySelection.new(
        name: selection.name,
        types: target_types,
        aliaz: selection.aliaz,
        arguments: selection.arguments,
        selections: selections_by_type,
        fragments: selection.fragments,
        metadata: {},
      )
    end

    def types_for_type(type)
      if type < Type
        [type]
      elsif type < Interface
        type.types
      else
        raise Error, "Unexpected type: #{type}"
      end
    end
  end
end
