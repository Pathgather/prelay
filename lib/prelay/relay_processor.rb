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
      # It's against the Relay spec for connections to be invoked without either
      # a 'first' or 'last' argument, but since the gem doesn't stop it from
      # happening, throw an error when/if that happens, just to be safe. If we
      # want to support that at some point (allowing the client to load all
      # records in a connection) we could, but that behavior should be thought
      # through, and a limit should probably still be applied to prevent abuse.
      unless selection.arguments[:first] || selection.arguments[:last]
        raise Error, "Tried to access the connection '#{selection.name}' without a 'first' or 'last' argument."
      end

      page_info = selection.selections.delete(:pageInfo)
      count     = selection.selections.delete(:count)

      if edges = selection.selections.delete(:edges)
        process_edge(edges)
        selection.selections = edges.selections
      end

      if page_info
        selection.metadata[:has_next_page]     = true if page_info.selections[:hasNextPage]
        selection.metadata[:has_previous_page] = true if page_info.selections[:hasPreviousPage]

        target_types.each do |type|
          (selection.selections[type] ||= {})[:id] ||= Selection.new(name: :id, types: [type])
        end
      end

      if count
        selection.metadata[:count_requested] = true
      end

      selection.types = target_types
      selection
    end

    def process_edge(selection)
      cursor = selection.selections.delete(:cursor)

      if node = selection.selections.delete(:node)
        process_field(node)
        selection.selections = node.selections
      end

      if cursor
        target_types.each do |type|
          (selection.selections[type] ||= {})[:cursor] ||= Selection.new(name: :cursor, types: [type])
        end
      end

      selection.types = target_types
      selection
    end

    def process_field(selection)
      raise Error, "Selection already typed! #{selection.inspect}" unless selection.types.nil?

      selection.types = target_types
      selections_by_type = {}
      target_types.each {|t| selections_by_type[t] = deep_copy(selection.selections)}
      selection.selections = selections_by_type

      # Now that we know the type, figure out if any of the fragments we set
      # aside earlier apply to this selection, and if so, resolve them.
      selection.fragments.each do |type, selection_sets|
        hashes = types_for_type(type).map{|l| selection.selections[l]}.compact

        hashes.each do |hash|
          selection_sets.each do |selection_set|
            selection_set.each do |key, new_attr|
              if old_attr = hash[key]
                # This field was already declared, so merge this selection with the
                # previous one. We don't yet support declaring the same field twice
                # with different arguments, so fail in that case.
                hash[key] = deep_copy(old_attr).merge!(deep_copy(new_attr), fail_on_argument_difference: true) if old_attr != new_attr
              else
                hash[key] = deep_copy(new_attr)
              end
            end
          end
        end
      end

      selection.selections.each do |type, selection_set|
        selection_set.each do |key, s|
          if type.attributes[s.name]
            # We're cool.
            process_field(s)
          elsif association = type.associations[s.name]
            entry_point = association.returns_array? ? :connection : :field
            self.class.new(s, target_types: association.target_types, entry_point: entry_point)
          else
            case s.name
            when :id
              process_field(s)
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

      selection
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

    # Hacky, but need a foolproof way to deep_copy some things until we have a
    # better handle on merging things.
    def deep_copy(thing)
      Marshal.load(Marshal.dump(thing))
    end
  end
end
