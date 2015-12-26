# frozen-string-literal: true

module Prelay
  class Selection
    attr_reader :name, :model, :arguments, :selections

    def initialize(name:, model: nil, arguments: {}, selections: {})
      @name       = name
      @model      = model
      @arguments  = arguments
      @selections = selections
    end

    def ==(other)
      self.class      == other.class &&
      self.name       == other.name &&
      self.model      == other.model &&
      self.arguments  == other.arguments &&
      self.selections == other.selections
    end

    def optimize!
      flatten_reciprocal_references!
      self
    end

    # Merges together two selections. Is recursive, so also merges
    # subselections, and their subselections, and...
    def merge!(other_selection, fail_on_argument_difference:)
      # We could be smarter about this (it's probably fine if the arguments
      # are identical), but don't add the complexity until we need it.
      if fail_on_argument_difference && (arguments.any? || other_selection.arguments.any?)
        raise InvalidGraphQLQuery.new("This query invokes the same field twice with arguments")
      end

      return other_selection if frozen?

      @selections = selections.merge(other_selection.selections) do |k, o, n|
        o.merge!(n, fail_on_argument_difference: fail_on_argument_difference)
      end

      self
    end

    # #optimize! is called recursively down the AST, and looks for references
    # to reciprocal associations whose selections can be pulled up to shallower
    # levels. Consider a GraphQL query like:

    # company_courses {
    #   id,
    #   name,
    #   user_course {
    #     id,
    #     launched_at,
    #     course {
    #       id,
    #       description,
    #     }
    #   }
    # }

    # The above query should be simplified so that the description is
    # retrieved for company_courses at the higher level, alongside id and
    # name, becoming equivalent to an AST generated from a query like:

    # company_courses {
    #   id,
    #   name,
    #   description,
    #   user_course {
    #     id,
    #     launched_at
    #   }
    # }

    # This simplification is necessary for Sequel's eager-loading to work
    # properly, but also reduces the number of queries we need to execute to
    # service that first GraphQL request.

    def flatten_reciprocal_references!(source_association: nil, source_ast: nil)
      model.associations.each do |key, association|
        # We don't care about selections that aren't associations.
        next unless selection = selections[key]

        # Look for the special case where the association is the reciprocal of
        # the association through which the ast is being optimized.
        if source_association && association.reciprocal_associations.include?(source_association)
          # When that happens, merge that part of the query into the upper
          # level and return true so that the higher level knows that a change
          # has been made and it needs to restart the optimization step.
          source_ast.merge!(selections.delete(key), fail_on_argument_difference: false)
          return true
        else
          # We're not going to modify this association, but its child
          # associations also need to be checked for optimization cases.
          {} while selection.flatten_reciprocal_references!(source_association: association, source_ast: self)
        end
      end

      false
    end
  end
end
