# frozen_string_literal: true

module Prelay
  class RelaySelection
    attr_reader :name, :type, :aliaz, :arguments

    def initialize(name:, type:, aliaz: nil, arguments: EMPTY_HASH)
      raise "RelaySelection initialized with a bad type: #{type.class}" unless type < Type

      @name      = name
      @type      = type
      @aliaz     = aliaz
      @arguments = arguments
    end

    def columns
      raise NotImplementedError
    end

    def associations
      raise NotImplementedError
    end

    def derived_dataset(order: nil, supplemental_columns: EMPTY_ARRAY)
      ds = type.model.dataset
      ds = ds.order(order) if order

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

      column_set = columns + supplemental_columns
      column_set.uniq!

      if column_set.delete(:cursor)
        order = ds.opts[:order]
        raise "Can't handle ordering by anything other than a single column!" unless order&.length == 1
        exp = unwrap_order_expression(order.first)
        column_set << Sequel.as(exp, :cursor)
      end

      selections = (ds.opts[:select] || EMPTY_ARRAY) + column_set.map{|c| qualify_column(ds.model.table_name, c)}

      if selections.count > 0
        ds = ds.select(*selections)
      end

      ds
    end

    def apply_pagination_to_dataset(ds)
      if limit = arguments[:first] || arguments[:last]
        ds = ds.reverse_order if arguments[:last]

        # If has_next_page or has_previous_page was requested, bump the limit
        # by one so we know whether there's another page coming up.
        limit += 1 if pagination_info_requested?

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

    private

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

    def unwrap_order_expression(oe)
      case oe
      when Sequel::SQL::OrderedExpression
        oe.expression
      else
        oe
      end
    end
  end
end
