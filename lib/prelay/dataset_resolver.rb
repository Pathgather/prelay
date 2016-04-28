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

    def initialize(selections_by_type:)
      @types = selections_by_type
    end

    def resolve
      records = []
      overall_order = nil
      count = 0

      @types.each do |type, ast|
        raise "Unexpected ast!: #{ast.class}" unless ast.is_a?(RelaySelection::ConnectionSelection)
        raise "Unexpected type!" unless type == ast.type

        ds = type.model.dataset
        ds = yield(ds)

        supplemental_columns = []
        supplemental_columns << :cursor if need_ordering_in_ruby?

        ds = apply_query_to_dataset(ds, type: type, supplemental_columns: supplemental_columns)

        if ast.count_requested?
          count += ds.unordered.unlimited.count
        end

        ds = apply_pagination_to_dataset(ds, type: type)

        derived_order = ds.opts[:order]
        overall_order ||= derived_order
        raise "Trying to merge results from datasets in different orders!" unless overall_order == derived_order

        records += results_for_dataset(ds, type: type)
      end

      # Each individual result set is sorted, now we need to make sure the
      # union is sorted as well.
      sort_records_by_order(records, overall_order) if need_ordering_in_ruby?

      r = ResultArray.new(records)
      r.total_count = count
      r
    end

    def resolve_singular
      # TODO: Can just stop iterating through types when we get a match.
      records = []

      @types.each do |type, ast|
        raise "Unexpected ast!: #{ast.class}" unless [RelaySelection::FieldSelection, RelaySelection::EdgeSelection].include?(ast.class)
        raise "Unexpected type!" unless type == ast.type

        ds = type.model.dataset
        ds = yield(ds)
        ds = apply_query_to_dataset(ds, type: type)

        records += results_for_dataset(ds, type: type)
      end

      raise "Too many records!" unless ZERO_OR_ONE === records.length

      records.first
    end

    protected

    def resolve_via_association(association, ids)
      return [EMPTY_RESULT_ARRAY, {}] if ids.none?

      block = association.sequel_association&.dig(:block)
      order = association.derived_order
      records = []
      remote_column = association.remote_columns.first # TODO: Multiple columns?
      overall_order = nil
      counts = {}

      @types.each do |type, ast|
        raise "Unexpected selection!" unless [RelaySelection::ConnectionSelection, RelaySelection::FieldSelection].include?(ast.class)
        raise "Unexpected type!" unless type == ast.type

        qualified_remote_column = Sequel.qualify(type.model.table_name, remote_column)

        ds = type.model.dataset
        ds = ds.order(order)

        supplemental_columns = [remote_column]
        supplemental_columns << :cursor if need_ordering_in_ruby?

        ds = apply_query_to_dataset(ds, type: type, supplemental_columns: supplemental_columns)

        ds = block.call(ds) if block
        ds = ds.where(qualified_remote_column => ids)

        if ast.count_requested?
          more_counts = ds.unlimited.unordered.from_self.group_by(remote_column).select_hash(remote_column, Sequel.as(Sequel.function(:count, Sequel.lit('*')), :count))
          counts = counts.merge(more_counts) { |k,o,n| o + n }
        end

        ds = apply_pagination_to_dataset(ds, type: type)

        derived_order = ds.opts[:order]
        overall_order ||= derived_order
        raise "Trying to merge results from datasets in different orders!" unless overall_order == derived_order

        if ids.length > 1 && limit = ds.opts[:limit]
          # Steal Sequel's technique for limiting eager-loaded associations with
          # a window function.
          ds = ds.
                unlimited.
                unordered.
                select_append(Sequel.function(:row_number).over(partition: qualified_remote_column, order: ds.opts[:order]).as(:prelay_row_number)).
                from_self.
                where { |r| r.<=(:prelay_row_number, limit) }
        end

        records += results_for_dataset(ds, type: type)
      end

      sort_records_by_order(records, overall_order) if need_ordering_in_ruby?

      [ResultArray.new(records), counts]
    end

    private

    def apply_query_to_dataset(ds, type:, supplemental_columns: EMPTY_ARRAY)
      ast       = @types.fetch(type)
      arguments = ast.arguments

      table_name = ds.model.table_name

      if scope = type.dataset_scope
        ds = scope.call(ds)
      end

      ([type] + type.interfaces.keys.reverse).each do |filter_source|
        filter_source.filters.each do |name, (type, block)|
          if value = arguments[name]
            ds = block.call(ds, value)
          end
        end
      end

      columns = ast.columns + supplemental_columns
      columns.uniq!

      if columns.delete(:cursor)
        order = ds.opts[:order]
        raise "Can't handle ordering by anything other than a single column!" unless order&.length == 1
        exp = unwrap_order_expression(order.first)
        columns << Sequel.as(exp, :cursor)
      end

      selections = (ds.opts[:select] || EMPTY_ARRAY) + columns.map{|c| qualify_column(table_name, c)}

      if selections.count > 0
        ds = ds.select(*selections)
      end

      ds
    end

    def apply_pagination_to_dataset(ds, type:)
      ast       = @types.fetch(type)
      arguments = ast.arguments

      if limit = arguments[:first] || arguments[:last]
        ds = ds.reverse_order if arguments[:last]

        # If has_next_page or has_previous_page was requested, bump the limit
        # by one so we know whether there's another page coming up.
        limit += 1 if ast.pagination_info_requested?

        ds =
          if cursor = arguments[:after] || arguments[:before]
            values = JSON.parse(Base64.decode64(cursor))

            expressions = ds.opts[:order].zip(values).map do |o, v|
              e = unwrap_order_expression(o)

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

    # If we're loading more than one type, and therefore executing more than
    # one query, we'll need to sort the combined results in Ruby. In other
    # words, to get the ten earliest posts + comments, we need to retrieve the
    # ten earliest posts, the ten earliest comments, concatenate them
    # together, sort them by their created_at, and take the first ten.
    def need_ordering_in_ruby?
      @types.length > 1
    end

    def sort_records_by_order(records, order)
      records.sort_by!{|r| r.record.values.fetch(:cursor)}

      o = order.is_a?(Array) ? order.first : order
      records.reverse! if o.is_a?(Sequel::SQL::OrderedExpression) && o.descending

      records
    end

    def unwrap_order_expression(oe)
      case oe
      when Sequel::SQL::OrderedExpression
        oe.expression
      else
        oe
      end
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
      else
        # Could be any arbitrary expression, like a function call or an SQL subquery.
        column
      end
    end

    def results_for_dataset(ds, type:)
      objects = ds.all.map{|r| type.new(r)}
      ResultArray.new(objects).tap { |results| process_associations_for_results(results, type: type) }
    end

    def process_associations_for_results(results, type:)
      return if results.empty?

      @types.fetch(type).associations.each do |key, (association, relay_processor)|
        # TODO: Figure out what it means to have multiple columns here.
        local_column  = association.local_columns.first
        remote_column = association.remote_columns.first

        ids = results.map{|r| r.record.send(local_column)}.uniq

        sub_records, counts = relay_processor.to_resolver.resolve_via_association(association, ids)
        sub_records_hash = {}

        if association.returns_array?
          sub_records.each do |r|
            results_array = sub_records_hash[r.record.send(remote_column)] ||= ResultArray.new([])
            results_array << r
          end

          counts.each do |id, count|
            sub_records_hash[id].total_count = count
          end

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
