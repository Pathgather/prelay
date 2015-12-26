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
    def initialize(ast:)
      @ast   = ast
      @model = ast.model
    end

    def resolve
      records = dataset.all
      process_associations_for_records(records)
      records
    end

    def resolve_by_id(id)
      # Make this is a valid uuid (and not nil) before we pass it to Postgres,
      # which would produce an uglier error.
      col = Sequel.qualify(@model.model.table_name, :id)
      records = dataset.where(col => id).all
      process_associations_for_records(records)
      records.first
    end

    def resolve_via_association(association, ids)
      return EMPTY_ARRAY if ids.none?

      reflection = association.sequel_association

      ds = @model.model.dataset

      if b = reflection[:block]
        ds = b.call(ds)
      end

      target_column =
        case reflection[:type]
        when :one_to_one, :one_to_many then reflection[:key]
        when :many_to_one              then reflection.primary_key
        else raise "Unsupported Sequel association type: #{reflection[:type].inspect}"
        end

      ds = apply_query_to_dataset(ds, supplemental_columns: [target_column])
      ds = ds.where(Sequel.qualify(@model.model.table_name, target_column) => ids)

      if ids.length > 1 && limit = ds.opts.delete(:limit)
        # Steal Sequel's technique for limiting eager-loaded associations with
        # a window function.
        ds = ds.
              unordered.
              select_append{|o| o.row_number{}.over(partition: target_column, order: ds.opts[:order]).as(:row_number)}.
              from_self.
              where{ |r| r.row_number <= limit}
      end

      records = ds.all

      process_associations_for_records(records)

      records
    end

    protected

    def apply_query_to_dataset(ds, supplemental_columns: [])
      table_name = @model.model.table_name
      arguments = @ast.arguments

      columns = (necessary_columns + supplemental_columns).uniq.map{|column| Sequel.qualify(table_name, column)}
      ds = ds.select(*columns).order(Sequel.qualify(table_name, :id))

      if limit = arguments[:first] || arguments[:last]
        ds = ds.reverse_order if arguments[:last]

        # If has_next_page was requested, bump the limit by one so we know
        # whether there's another page coming up.
        limit += 1 if arguments[:has_next_page] || arguments[:has_previous_page]

        ds =
          if relay_id = arguments[:after] || arguments[:before]
            pk = RelayID.parse(relay_id, expected_type: @model.graphql_name).uuid
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
        reflection = association.sequel_association
        type = reflection[:type]

        ids =
          case type
          when :one_to_one, :one_to_many
            records.map(&reflection.primary_key)
          when :many_to_one
            # TODO: Make sure that this key column was loaded in the initial record load.
            records.map(&reflection[:key]).uniq
          else
            raise "Unsupported reflection type: #{type}"
          end

        sub_records = dataset_resolver.resolve_via_association(association, ids)

        case type
        when :one_to_one
          sub_records_hash = sub_records.index_by(&reflection[:key])
          records.each do |r|
            associated_record = sub_records_hash[r.send(reflection.primary_key)]
            r.associations[reflection[:name]] = associated_record
            associated_record.associations[reflection.reciprocal] = r if associated_record
          end
        when :many_to_one
          sub_records_hash = {}
          sub_records.each{|r| sub_records_hash[r.send(reflection.primary_key)] = r}
          records.each do |r|
            associated_record = sub_records_hash[r.send(reflection[:key])]
            r.associations[reflection[:name]] = associated_record
            associated_record.associations[reflection.reciprocal] = r
          end
        when :one_to_many
          sub_records_hash = {}
          sub_records.each do |r|
            k = r.send(reflection[:key])
            (sub_records_hash[k] ||= []) << r
          end
          records.each do |r|
            associated_records = sub_records_hash[r.send(reflection.primary_key)]
            r.associations[reflection[:name]] = associated_records
            associated_records.each {|ar| ar.associations[reflection.reciprocal] = r}
          end
        else
          raise "Unsupported reflection type: #{type}"
        end
      end
    end

    def dataset
      apply_query_to_dataset(@model.model.dataset)
    end

    def necessary_columns
      @columns || calculate_columns_and_associations && @columns
    end

    def associations
      @associations || calculate_columns_and_associations && @associations
    end

    def calculate_columns_and_associations
      @columns      = []
      @associations = {}

      @ast.selections.each_value do |selection|
        name = selection.name

        if name == :id
          # Id isn't a true attribute, but we'll need the record's UUID to
          # generate its opaque id.
          @columns << :id
        elsif attribute = @model.attributes[name]
          @columns.push(*attribute.dependent_columns)
        elsif association = @model.associations[name]
          @columns.push(*association.dependent_columns)
          @associations[association] = self.class.new(ast: selection)
        else
          # This should only happen if we've messed up the conversion from the
          # model definition to the GraphQL type declaration somehow - a
          # client sending a weird request should be caught before this.
          raise "Unrecognized GraphQL selection for #{@model}: #{name}"
        end
      end
    end
  end
end
