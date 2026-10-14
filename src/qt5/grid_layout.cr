module Qt
  class GridLayout
    # Places *item* in the cell at *column*|*row*.  The *row* and/or *column*
    # can be a `Range`, in which case the given *item* will cover all cells in
    # the given ranges.
    #
    # The *item* may be a `Widget`, a `Layout`, a `LayoutItem`, or respond to
    # `#as_layout_item`.
    def []=(column : Int32 | Range, row : Int32 | Range, item)
      row_start, row_span = resolve_range(row, &.row_count)
      column_start, column_span = resolve_range(column, &.column_count)

      case item
      when Widget     then add_widget(item, row_start, column_start, row_span, column_span)
      when Layout     then add_layout(item, row_start, column_start, row_span, column_span)
      when LayoutItem then add_item(item, row_start, column_start, row_span, column_span)
      else                 add_item(item.as_layout_item, row_start, column_start, row_span, column_span)
      end

      item
    end

    # Resolves *index*: If it is less than zero, it "wraps around" the available
    # space of rows or columns.
    private def resolve_index(index, off_by_one = false, &) : Int32
      index -= 1 if off_by_one

      if index < 0
        yield(self) + index
      else
        index
      end
    end

    # Resolves a *range* which is just a single integer.  Defaults to a span of
    # one.
    private def resolve_range(range : Int32, &)
      start = resolve_index(range) { |x| yield x }
      {start, 1}
    end

    # Resolves a *range*, supporting multi-cell spans.
    private def resolve_range(range : Range(Int32, Int32), &)
      start = resolve_index(range.begin) { |x| yield x }
      last = resolve_index(range.end, range.exclusive?) { |x| yield x }

      if last <= start
        raise IndexError.new("Last element must be greater than first element in #{range}")
      end

      {start, last - start}
    end
  end
end
