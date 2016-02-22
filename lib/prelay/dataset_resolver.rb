# frozen_string_literal: true

# The purpose of the DatasetResolver class is to take a GraphQL AST describing
# the attributes and associations that are desired in a query, and then
# construct a set of DB queries to fulfill the request correctly and
# efficiently. The "correctly" part requires applying the appropriate filters
# to the query, while "efficiently" requires some thought about retrieving
# only the columns we need from the DB and manually eager-loading the
# appropriate associations.

require 'prelay/result_array'

module Prelay
  class DatasetResolver
    ZERO_OR_ONE = 0..1
    EMPTY_RESULT_ARRAY = ResultArray.new(EMPTY_ARRAY).freeze

    def initialize(ast:)
      @types     = {}
      @arguments = ast.arguments
      @metadata  = ast.metadata

      ast.selections.each do |type, selections|
        type_data    = @types[type] ||= {}
        columns      = type_data[:columns] ||= []
        associations = type_data[:associations] ||= {}

        fields = {}
        selections.each do |key, selection|
          name = selection.name
          fields[name] ||= []
          fields[name] << selection
        end

        # id isn't a true attribute, but we'll need it to generate the record's
        # relay id.
        if fields.delete(:id)
          columns << :id
        end

        if fields.delete(:cursor)
          # Will need to special-case requests for the cursor.
          columns << :cursor
        end

        type.attributes.each do |name, attribute|
          # Will need to be a little smarter here if we want to support fields
          # with arguments that need to be pushed down to the DB.
          if fields.delete(name)
            columns.push *attribute.dependent_columns
          end
        end

        type.associations.each do |name, association|
          if selections = fields.delete(name)
            selections.each do |selection|
              key = selection.aliaz || selection.name
              columns.push *association.local_columns
              associations[key] = [association, self.class.new(ast: selection)]
            end
          end
        end

        raise "Unrecognized fields for #{type}: #{fields.inspect}" if fields.any?

        columns.uniq!
      end
    end

    def resolve
      records = []
      overall_order = nil

      @types.each_key do |type|
        ds = type.model.dataset
        ds = yield(ds)

        supplemental_columns = []
        supplemental_columns << :cursor if @types.length > 1

        ds = apply_query_to_dataset(ds, type: type, supplemental_columns: supplemental_columns)

        derived_order = ds.opts[:order]
        overall_order ||= derived_order
        raise "Trying to merge results from datasets in different orders!" unless overall_order == derived_order

        records += results_for_dataset(ds, type: type)
      end

      # Each individual result set is sorted, now we need to make sure the
      # union is sorted as well.
      sort_records_by_order(records, overall_order) if @types.length > 1

      ResultArray.new(records)
    end

    def resolve_singular
      # TODO: Can just stop iterating through types when we get a match.
      records = []

      @types.each_key do |type|
        ds = type.model.dataset
        ds = yield(ds)
        ds = apply_query_to_dataset(ds, type: type)

        records += results_for_dataset(ds, type: type)
      end

      raise "Too many records!" unless ZERO_OR_ONE === records.length

      records.first
    end

    def resolve_via_association(association, ids)
      return EMPTY_RESULT_ARRAY if ids.none?

      block = association.sequel_association&.dig(:block)
      order = association.derived_order
      records = []
      remote_column = association.remote_columns.first # TODO: Multiple columns?
      overall_order = nil

      @types.each_key do |type|
        qualified_remote_column = Sequel.qualify(type.model.table_name, remote_column)

        ds = type.model.dataset
        ds = ds.order(order)

        supplemental_columns = [remote_column]
        supplemental_columns << :cursor if @types.length > 1

        ds = apply_query_to_dataset(ds, type: type, supplemental_columns: supplemental_columns)

        derived_order = ds.opts[:order]
        overall_order ||= derived_order
        raise "Trying to merge results from datasets in different orders!" unless overall_order == derived_order

        ds = block.call(ds) if block
        ds = ds.where(qualified_remote_column => ids)

        if ids.length > 1 && limit = ds.opts.delete(:limit)
          # Steal Sequel's technique for limiting eager-loaded associations with
          # a window function.
          ds = ds.
                unordered.
                select_append(Sequel.function(:row_number).over(partition: qualified_remote_column, order: ds.opts[:order]).as(:prelay_row_number)).
                from_self.
                where { |r| r.<=(:prelay_row_number, limit) }
        end

        records += results_for_dataset(ds, type: type)
      end

      sort_records_by_order(records, overall_order) if @types.length > 1

      ResultArray.new(records)
    end

    protected

    def apply_query_to_dataset(ds, type:, supplemental_columns: EMPTY_ARRAY)
      table_name = ds.model.table_name

      if scope = type.dataset_scope
        ds = scope.call(ds)
      end

      type.filters.each do |name, (type, block)|
        if value = @arguments[name]
          ds = block.call(ds, value)
        end
      end

      columns = @types[type][:columns] + supplemental_columns
      columns.uniq!

      if columns.delete(:cursor)
        order = ds.opts[:order]
        raise "Can't handle ordering by anything other than a single column!" unless order&.length == 1

        exp =
          case o = order.first
          when Sequel::SQL::OrderedExpression then o.expression
          else o
          end

        columns << Sequel.as(exp, :cursor)
      end

      selections = ds.opts[:select] || EMPTY_ARRAY

      ds = ds.select(*(selections + columns.map{|c| qualify_column(table_name, c)}))

      if limit = @arguments[:first] || @arguments[:last]
        ds = ds.reverse_order if @arguments[:last]

        # If has_next_page or has_previous_page was requested, bump the limit
        # by one so we know whether there's another page coming up.
        limit += 1 if @metadata[:has_next_page] || @metadata[:has_previous_page]

        ds =
          if cursor = @arguments[:after] || @arguments[:before]
            values = JSON.parse(Base64.decode64(cursor))

            expressions = ds.opts[:order].zip(values).map do |o, v|
              e = o.expression

              if e.is_a?(Sequel::SQL::Function) && e.name == :ts_rank_cd
                # Minor hack for full-text search, which returns reals when
                # Sequel assumes floats are double precision.
                Sequel.cast(v, :real)
              elsif e == :created_at
                Time.at(*v) # value should be an array of two integers, seconds and microseconds.
              else
                v
              end
            end

            ds.seek_paginate(limit, after: expressions)
          else
            ds.seek_paginate(limit)
          end
      end

      ds
    end

    private

    def sort_records_by_order(records, order)
      records.sort_by!{|r| r.record.values.fetch(:cursor)}

      o = order.is_a?(Array) ? order.first : order
      records.reverse! if o.is_a?(Sequel::SQL::OrderedExpression) && o.descending

      records
    end

    def qualify_column(table_name, column)
      case column
      when Symbol
        Sequel.qualify(table_name, column)
      when Sequel::SQL::AliasedExpression
        Sequel.as(qualify_column(table_name, column.expression), column.aliaz)
      when Sequel::SQL::QualifiedIdentifier
        # TODO: Figure out when/how this happens and stop it.
        raise "Table qualification mismatch: #{column.table.inspect}, #{table_name.inspect}" unless column.table == table_name
        column
      when Sequel::SQL::Function
        column
      else
        raise "Unexpected thing to qualify: #{column.class}"
      end
    end

    def results_for_dataset(ds, type:)
      objects = ds.all.map{|r| type.new(r)}
      ResultArray.new(objects).tap { |results| process_associations_for_results(results, type: type) }
    end

    def process_associations_for_results(results, type:)
      return if results.empty?

      @types[type][:associations].each do |key, (association, dataset_resolver)|
        # TODO: Figure out what it means to have multiple columns here.
        local_column  = association.local_columns.first
        remote_column = association.remote_columns.first

        ids = results.map{|r| r.record.send(local_column)}.uniq

        sub_records = dataset_resolver.resolve_via_association(association, ids)
        sub_records_hash = {}

        if association.returns_array?
          sub_records.each { |r| (sub_records_hash[r.record.send(remote_column)] ||= ResultArray.new([])) << r }

          results.each do |r|
            associated_records = sub_records_hash[r.record.send(local_column)] || ResultArray.new([])
            r.associations[key] = associated_records
          end
        else
          sub_records.each{|r| sub_records_hash[r.record.send(remote_column)] = r}

          results.each do |r|
            associated_record = sub_records_hash[r.record.send(local_column)]
            r.associations[key] = associated_record
          end
        end
      end
    end
  end
end
