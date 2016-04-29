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
    EMPTY_RESULT_ARRAY = ResultArray.new(EMPTY_ARRAY).freeze

    def initialize(selections_by_type:, order: nil, supplemental_columns: [], &block)
      @asts = selections_by_type
      @datasets = {}
      @paginated_datasets = {}

      selections_by_type.each do |type, ast|
        ds = ast.derived_dataset(order: order, supplemental_columns: supplemental_columns, need_cursor: need_ordering_in_ruby?)
        ds = yield ds if block_given?

        @datasets[type] = ds
        @paginated_datasets[type] = ast.apply_pagination_to_dataset(ds)
      end
    end

    def resolve
      records = []
      count = 0

      @paginated_datasets.each do |type, ds|
        records += results_for_dataset(ds, type: type)
      end

      # If one AST requests the count, they all will.
      if @asts.values.first.count_requested?
        @datasets.each_value do |ds|
          count += ds.unordered.unlimited.count
        end
      end

      # Each individual result set is sorted, now we need to make sure the
      # union is sorted as well.
      sort_records(records) if need_ordering_in_ruby?

      ResultArray.new(records).tap { |r| r.total_count = count }
    end

    def resolve_singular
      records = []

      @datasets.each do |type, ds|
        records += results_for_dataset(ds, type: type)
      end

      raise Error, "#resolve_singular returned more than one record! (returned #{records.length})" if records.length > 1

      records.first
    end

    protected

    def resolve_via_association(association, ids)
      return EMPTY_HASH if ids.empty?

      records = {}
      remote_column = association.remote_columns.first # TODO: Multiple columns?

      @paginated_datasets.each do |type, ds|
        qualified_remote_column = Sequel.qualify(type.model.table_name, remote_column)

        counts =
          if @asts[type].count_requested?
            @datasets[type].unlimited.unordered.from_self.group_by(remote_column).select_hash(remote_column, Sequel.as(Sequel.function(:count, Sequel.lit('*')), :count))
          else
            EMPTY_HASH
          end

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
        else
          results.each do |result|
            fk = result.record.send(remote_column)
            records[fk] = result
          end
        end
      end

      if association.returns_array?
        records.each do |fk, subrecords|
          sort_records(subrecords) if need_ordering_in_ruby?
        end
      end

      records
    end

    private

    def overall_order
      @overall_order ||=
        begin
          overall_order = nil

          @paginated_datasets.each_value do |ds|
            derived_order = ds.opts[:order]
            overall_order ||= derived_order
            raise Error, "Trying to merge results from datasets in different orders!" unless overall_order == derived_order
          end

          overall_order
        end
    end

    # If we're loading more than one type, and therefore executing more than
    # one query, we'll need to sort the combined results in Ruby. In other
    # words, to get the ten earliest posts + comments, we need to retrieve the
    # ten earliest posts, the ten earliest comments, concatenate them
    # together, sort them by their created_at, and take the first ten.
    def need_ordering_in_ruby?
      @asts.length > 1
    end

    def sort_records(records)
      sort_datas = @asts.values.map(&:sort_data)
      raise Error, "Weird sort condition: #{sort_datas.inspect}" unless sort_datas.uniq.length == 1
      sort_data = sort_datas.first.map{|s| s[1..2]}

      records.sort! { |r1, r2| sort_compare(r1, r2, sort_data) }
    end

    def sort_compare(r1, r2, sort_data)
      sort_data.each_with_index do |(dir, nulls), index|
        v1 = r1.cursor[index]
        v2 = r2.cursor[index]

        # Don't handle nulls, yet.
        c = v1 <=> v2
        c = -c if dir == :desc
        return c unless c.zero?
      end

      # TODO: Raise (or just warn) when a stable sort can't be achieved?
      0
    end

    def results_for_dataset(ds, type:)
      ast = @asts[type]

      objects =
        if sort_data = ast.sort_data
          sort_columns = sort_data.map(&:first)

          ds.all.map do |r|
            t = type.new(r)
            t.cursor = r.values.values_at(*sort_columns)
            t
          end
        else
          ds.all.map { |r| type.new(r) }
        end

      ResultArray.new(objects).tap { |results| process_associations_for_results(results, type: type) }
    end

    def process_associations_for_results(results, type:)
      return if results.empty?

      @asts.fetch(type).associations.each do |key, (association, relay_processor)|
        local_column  = association.local_columns.first
        remote_column = association.remote_columns.first

        ids = results.map{|r| r.record.send(local_column)}.compact.uniq

        order = association.derived_order
        block = association.sequel_association&.dig(:block)

        resolver = relay_processor.to_resolver(order: order, supplemental_columns: [remote_column]) do |ds|
          qualified_remote_column = Sequel.qualify(ds.model.table_name, remote_column)
          ds = ds.where(qualified_remote_column => ids)
          ds = block.call(ds) if block
          ds
        end

        records_hash = resolver.resolve_via_association(association, ids)

        if association.returns_array?
          results.each do |r|
            r.associations[key] = records_hash[r.record.send(local_column)] || EMPTY_RESULT_ARRAY
          end
        else
          results.each do |r|
            r.associations[key] = records_hash[r.record.send(local_column)]
          end
        end
      end
    end
  end
end
