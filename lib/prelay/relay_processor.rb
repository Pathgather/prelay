# frozen_string_literal: true

module Prelay
  class RelayProcessor
    attr_reader :ast, :types_to_skip
    attr_accessor :current_type

    # The calling code should know if the field being passed in is a Relay
    # connection or edge call, so it must provide an :entry_point argument to
    # tell us how to start parsing.
    def initialize(input, type:, types_to_skip: nil, entry_point:)
      @types_to_skip = types_to_skip || EMPTY_ARRAY

      @ast =
        scope_type(type) do
          case entry_point
          when :field      then process_field(input)
          when :connection then process_connection(input)
          when :edge       then process_edge(input)
          else raise "Unsupported entry_point: #{entry_point}"
          end
        end
    end

    def to_resolver
      DatasetResolver.new(ast: @ast)
    end

    private

    def process_connection(selection)
      raise "Can't yet handle connections without edges" unless edges = selection.selections.delete(:edges)
      process_edge(edges)

      # It's against the Relay spec for connections to be invoked without either
      # a 'first' or 'last' argument, but since the gem doesn't stop it from
      # happening, throw an error when/if that happens, just to be safe. If we
      # want to support that at some point (allowing the client to load all
      # records in a connection) we could, but that behavior should be thought
      # through, and a limit should probably still be applied to prevent abuse.
      unless selection.arguments[:first] || selection.arguments[:last]
        raise InvalidGraphQLQuery, "Tried to access the connection '#{selection.name}' without a 'first' or 'last' argument."
      end

      if page_info = selection.selections.delete(:pageInfo)
        selection.metadata[:has_next_page]     = true if page_info.selections[:hasNextPage]
        selection.metadata[:has_previous_page] = true if page_info.selections[:hasPreviousPage]
      end

      selection.selections = edges.selections
      selection.type = current_type
      selection
    end

    def process_edge(selection)
      # TODO: Don't require a 'node' field, as it's valid to just do a query to
      # get cursors.
      raise "Can't yet handle edges without nodes" unless node = selection.selections.delete(:node)
      process_field(node)

      if cursor = selection.selections.delete(:cursor)
        target_types.each do |type|
          node.selections[type][:cursor] ||= Selection.new(name: :cursor, type: type)
        end
      end

      selection.selections = node.selections
      selection.type = current_type
      selection
    end

    def process_field(selection)
      raise "Selection already typed! #{selection.inspect}" unless selection.type.nil?

      type = current_type
      selection.type = type
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
            scope_type(association.target_type) do
              if association.returns_array?
                process_connection(s)
              else
                process_field(s)
              end
            end
          else
            case s.name
            when :id
              process_field(s)
            when :clientMutationId, :__typename
              # These are acceptable fields to request, but the GraphQL gem
              # handles them, so we can just ignore them.
              selection_set.delete(key)
            else
              raise InvalidGraphQLQuery, "unsupported field '#{s.name}'"
            end
          end
        end
      end

      selection
    end

    def target_types
      types_for_type(current_type) - types_to_skip
    end

    def types_for_type(type)
      if type < Type
        [type]
      elsif type < Interface
        type.types
      else
        raise "Unexpected type: #{type}"
      end
    end

    # Hacky, but need a foolproof way to deep_copy some things until we have a
    # better handle on merging things.
    def deep_copy(thing)
      Marshal.load(Marshal.dump(thing))
    end

    # Super-simple scoping of the current type class as we walk the AST.
    def scope_type(type)
      previous_type = current_type
      self.current_type = type
      yield
    ensure
      self.current_type = previous_type
    end
  end
end
