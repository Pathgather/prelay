# frozen_string_literal: true

module Prelay
  class SequelConnection < GraphQL::Relay::BaseConnection
    def cursor_from_node(node)
      cursor = node.record.values.fetch(:cursor) { raise "Uh-oh! Cursor not loaded for #{node.inspect}" }

      # Array(Time.now) behaves weirdly.
      cursor = [cursor] unless cursor.is_a?(Array)

      cursor.map! do |value|
        case value
        when Time then [value.to_i, value.usec] # Using #to_f results in floating point inaccuracy :(
        else value
        end
      end

      Base64.strict_encode64(cursor.to_json)
    end

    def count
      object.count
    end

    def sliced_nodes
      # This is where 'before' and 'after' options would be applied, but we did
      # that at the eager-loading level so there's nothing more to do here.
      object
    end

    def paged_nodes
      # Apply 'first' and 'last' options.

      # When hasNext/PreviousPage is provided in the query, we bump up the limit
      # in the eager loading process so that we know whether those pages exist,
      # so now we need to make sure we return the appropriate number of objects,
      # rather than too many.
      if first
        object.first(first)
      else
        # If the 'last' option is passed we reversed the ORDER BY in the eager
        # loading step, so now we need to reverse the actual array of returned
        # objects so that Relay gets them in the order it wants.
        object.reverse.last(last)
      end
    end

    # hasPreviousPage doesn't seem to have a lot of utility when paginating
    # forward (with a 'first' argument rather than a 'last' one). Either an
    # 'after' argument was given, in which case it makes sense to assume that
    # there actually is something that's being paginated after (if an id was
    # passed for a record that is now missing, seek pagination would have
    # errored). Or an 'after' argument wasn't given, in which case we're
    # starting from the very beginning of the dataset so of course there's no
    # previous page. In other words, it seems like Relay should be able to
    # figure out hasPreviousPage for itself when paginating forward in any
    # circumstance. However, it still asks for both hasNextPage and
    # hasPreviousPage on every query, so we do a little extra work to make sure
    # both answers are always accurate.

    # Note: Revisit these assumptions once cursors contain sorting information
    # rather than object ids.

    def has_previous_page
      if last
        object.length > last
      else
        !!after
      end
    end

    # The same is all true for hasNextPage when paginating in reverse.
    def has_next_page
      if first
        object.length > first
      else
        !!before
      end
    end
  end
end
