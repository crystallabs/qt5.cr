module Qt
  class GridLayout
    # Places *item* in the cell at *row* and *column*, in the order of
    # `#add_widget(item, row, column)`.  The *row* and/or *column* can be a
    # `Range`, in which case the given *item* will cover all cells in the given
    # ranges.  A negative index counts from the last row or column.
    #
    # ```
    # grid[0, 1] = Qt::Label.new("Row 0, column 1")
    # grid[1, 0..1] = Qt::Label.new("Row 1, columns 0 and 1")
    # ```
    #
    # The *item* may be a `Widget`, a `Layout`, a `LayoutItem`, or respond to
    # `#as_layout_item`.
    def []=(row : Int32 | Range, column : Int32 | Range, item)
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
    private def resolve_index(index, &) : Int32
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
      last = resolve_index(range.end) { |x| yield x }
      last -= 1 if range.exclusive?

      if last < start
        raise IndexError.new("Range #{range} covers no cell")
      end

      {start, last - start + 1}
    end
  end
end
