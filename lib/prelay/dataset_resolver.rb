# frozen-string-literal: true

# The purpose of the DatasetResolver class is to take a GraphQL AST describing
# the attributes and associations that are desired in a query, and then
# construct a set of DB queries to fulfill the request correctly and
# efficiently. The "correctly" part requires applying the appropriate filters
# to the query, while "efficiently" requires some thought about retrieving
# only the columns we need from the DB and manually eager-loading the
# appropriate associations.

module Prelay
  class DatasetResolver
    def initialize(selection:)
      @type      = selection.type
      @arguments = selection.arguments
      @metadata  = selection.metadata

      @columns      = []
      @associations = {}

      # Will eventually need to do something smarter here when we want to
      # support multiple invocations of the same attribute with different
      # arguments.
      fields = {}
      selection.attributes.each do |aliaz, selection|
        fields[selection.name] = selection
      end

      # id isn't a true attribute, but we'll need it to generate the record's
      # relay id.
      if fields.delete(:id)
        @columns << :id
      end

      @type.attributes.each do |name, attribute|
        if fields.delete(name)
          @columns.push *attribute.dependent_columns
        end
      end

      @type.associations.each do |name, association|
        if s = fields.delete(name)
          @columns << association.local_column
          @associations[association] = self.class.new(selection: s)
        end
      end

      raise "Unrecognized fields for #{@type}: #{fields.inspect}" if fields.any?
    end

    def resolve
      ResultArray.new(dataset.all).tap { |records| process_associations_for_records(records) }
    end

    def resolve_by_pk(pk)
      cond = @type.model.qualified_primary_key_hash(pk)
      ResultArray.new(dataset.where(cond).all).tap{|records| process_associations_for_records(records)}.first
    end

    def resolve_via_association(association, ids)
      return ResultArray.new([]) if ids.none?

      reflection = association.sequel_association

      ds = @type.model.dataset

      if b = reflection[:block]
        ds = b.call(ds)
      end

      target_column = association.remote_column
      qualified_target_column = Sequel.qualify(@type.model.table_name, target_column)

      ds = apply_query_to_dataset(ds, supplemental_columns: [target_column])
      ds = ds.where(qualified_target_column => ids)

      if ids.length > 1 && limit = ds.opts.delete(:limit)
        # Steal Sequel's technique for limiting eager-loaded associations with
        # a window function.
        ds = ds.
              unordered.
              select_append{|o| o.row_number{}.over(partition: qualified_target_column, order: ds.opts[:order]).as(:prelay_row_number)}.
              from_self.
              where{ |r| r.prelay_row_number <= limit}
      end

      ResultArray.new(ds.all).tap { |records| process_associations_for_records(records) }
    end

    protected

    def apply_query_to_dataset(ds, supplemental_columns: [])
      table_name = @type.model.table_name
      arguments = @arguments

      columns = (@columns + supplemental_columns).uniq.map{|column| Sequel.qualify(table_name, column)}
      ds = ds.select(*columns).order(Sequel.qualify(table_name, :id))

      if limit = arguments[:first] || arguments[:last]
        ds = ds.reverse_order if arguments[:last]

        # If has_next_page was requested, bump the limit by one so we know
        # whether there's another page coming up.
        limit += 1 if @metadata[:has_next_page] || @metadata[:has_previous_page]

        ds =
          if id = arguments[:after] || arguments[:before]
            pk = ID.parse(id, expected_type: @type.graphql_object.name).pk
            ds.seek_paginate(limit, after_pk: pk)
          else
            ds.seek_paginate(limit)
          end
      end

      ds
    end

    private

    def process_associations_for_records(records)
      @associations.each do |association, dataset_resolver|
        reflection       = association.sequel_association
        association_name = reflection[:name]
        reciprocal       = reflection.reciprocal
        local_column     = association.local_column
        remote_column    = association.remote_column

        ids = records.map(&local_column).uniq

        sub_records = dataset_resolver.resolve_via_association(association, ids)
        sub_records_hash = {}

        if association.returns_array?
          sub_records.each { |r| (sub_records_hash[r.send(remote_column)] ||= ResultArray.new([])) << r }

          records.each do |r|
            associated_records = sub_records_hash[r.send(local_column)] || ResultArray.new([])
            r.associations[association_name] = associated_records
          end
        else
          sub_records.each{|r| sub_records_hash[r.send(remote_column)] = r}

          records.each do |r|
            associated_record = sub_records_hash[r.send(local_column)]
            r.associations[association_name] = associated_record
          end
        end
      end
    end

    def dataset
      apply_query_to_dataset(@type.model.dataset)
    end
  end
end
