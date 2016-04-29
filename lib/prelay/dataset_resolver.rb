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

    def initialize(selections_by_type:, order: nil)
      @types = selections_by_type
      @order = order
    end

    def resolve
      records = []
      overall_order = nil
      count = 0

      @types.each do |type, ast|
        supplemental_columns = []
        supplemental_columns << :cursor if need_ordering_in_ruby?

        ds = ast.derived_dataset(order: @order, supplemental_columns: supplemental_columns)
        ds = yield(ds) if block_given?

        if ast.count_requested?
          count += ds.unordered.unlimited.count
        end

        ds = ast.apply_pagination_to_dataset(ds)

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
        ds = ast.derived_dataset(order: @order)
        ds = yield(ds) if block_given?

        records += results_for_dataset(ds, type: type)
      end

      raise "Too many records!" unless ZERO_OR_ONE === records.length

      records.first
    end

    protected

    def resolve_via_association(association, ids)
      return {} if ids.none?

      block = association.sequel_association&.dig(:block)
      order = association.derived_order
      records = {}
      remote_column = association.remote_columns.first # TODO: Multiple columns?
      overall_order = nil

      @types.each do |type, ast|
        qualified_remote_column = Sequel.qualify(type.model.table_name, remote_column)

        supplemental_columns = [remote_column]
        supplemental_columns << :cursor if need_ordering_in_ruby?

        ds = ast.derived_dataset(order: order, supplemental_columns: supplemental_columns)

        ds = block.call(ds) if block
        ds = ds.where(qualified_remote_column => ids)

        counts =
          if ast.count_requested?
            ds.unlimited.unordered.from_self.group_by(remote_column).select_hash(remote_column, Sequel.as(Sequel.function(:count, Sequel.lit('*')), :count))
          else
            {}
          end

        ds = ast.apply_pagination_to_dataset(ds)

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

        results = results_for_dataset(ds, type: type)

        if association.returns_array?
          results.each do |result|
            fk = result.record.send(remote_column)
            (records[fk] ||= ResultArray.new([])) << result
          end

          counts.each do |fk, count|
            records[fk].total_count += count
          end

          records.each do |fk, subrecords|
            sort_records_by_order(subrecords, overall_order) if need_ordering_in_ruby?
          end
        else
          results.each do |result|
            fk = result.record.send(remote_column)
            records[fk] = result
          end
        end
      end

      records
    end

    private

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

    def results_for_dataset(ds, type:)
      objects = ds.all.map{|r| type.new(r)}
      ResultArray.new(objects).tap { |results| process_associations_for_results(results, type: type) }
    end

    def process_associations_for_results(results, type:)
      return if results.empty?

      @types.fetch(type).associations.each do |key, (association, relay_processor)|
        local_column = association.local_columns.first
        ids = results.map{|r| r.record.send(local_column)}.uniq
        sub_records_hash = relay_processor.to_resolver.resolve_via_association(association, ids)

        if association.returns_array?
          results.each do |r|
            associated_records = sub_records_hash[r.record.send(local_column)] || ResultArray.new([])
            r.associations[key] = associated_records
          end
        else
          results.each do |r|
            associated_record = sub_records_hash[r.record.send(local_column)]
            r.associations[key] = associated_record
          end
        end
      end
    end
  end
end
