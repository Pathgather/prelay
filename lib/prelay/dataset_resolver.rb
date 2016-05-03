# frozen_string_literal: true

# The DatasetResolver class takes one or more RelaySelection ASTs, gathers
# their associated datasets and aggregates query results (mainly records, but
# this might also be other aggregate data like counts). It also handles eager-
# loading result sets through associations as necessary.

# The case where there are multiple ASTs reflects queries that touch multiple
# types (queries on interfaces, for example).

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
      remote_column = association.remote_column
      unqualified_remote_column = unqualify_column(remote_column)

      @paginated_datasets.each do |type, ds|
        qualified_remote_column = qualify_column(remote_column, type.model.table_name)

        counts =
          if @asts[type].count_requested?

            @datasets[type].unlimited.unordered.from_self.
              group_by(unqualified_remote_column).
              select_hash(unqualified_remote_column, Sequel.as(Sequel.function(:count, Sequel.lit('*')), :count))
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
            fk = result.record[unqualified_remote_column]
            (records[fk] ||= ResultArray.new([])) << result
          end

          counts.each do |fk, count|
            records[fk].total_count += count
          end
        else
          results.each do |result|
            fk = result.record[unqualified_remote_column]
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

    def unqualify_column(exp)
      case exp
      when Sequel::SQL::QualifiedIdentifier
        exp.column
      else
        exp
      end
    end

    def qualify_column(exp, qualifier)
      case exp
      when Sequel::SQL::QualifiedIdentifier
        exp
      else
        Sequel.qualify(qualifier, exp)
      end
    end

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

      raise Error, "Couldn't determine a stable sort for records #{r1.inspect} and #{r2.inspect}! Be sure to sort on a unique set of columns!"
    end

    def results_for_dataset(ds, type:)
      objects =
        if sort_data = @asts[type].sort_data
          sort_columns = sort_data.map(&:first)
          ds.all.map { |r| type.new(r, r.values.values_at(*sort_columns)) }
        else
          ds.all.map { |r| type.new(r) }
        end

      ResultArray.new(objects).tap { |results| process_associations_for_results(results, type: type) }
    end

    def process_associations_for_results(results, type:)
      return if results.empty?

      @asts.fetch(type).associations.each do |key, (association, relay_processor)|
        local_column  = association.local_column
        remote_column = association.remote_column

        ids = results.map{|r| r.record.send(local_column)}.compact.uniq
        order = association.derived_order
        block = association.dataset_block

        resolver = relay_processor.to_resolver(order: order, supplemental_columns: [remote_column]) do |ds|
          qualified_remote_column = qualify_column(remote_column, ds.model.table_name)
          ds = block.call(ds) if block
          ds = ds.where(qualified_remote_column => ids)
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
