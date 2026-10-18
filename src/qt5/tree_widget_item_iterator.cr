module Qt
  # Iterates the items of a `TreeWidget`, or the sub-tree of a
  # `TreeWidgetItem`, in the order they're shown.
  #
  # ```
  # Qt::TreeWidgetItemIterator.new(tree).each { |item| puts item.text(0) }
  # ```
  class TreeWidgetItemIterator
    include Iterator(TreeWidgetItem)

    # Returns the current item, or `nil` past the last one.
    def value : TreeWidgetItem?
      deref
    end

    # Returns the current item and advances, see `Iterator#next`.
    def next : TreeWidgetItem | Iterator::Stop
      if item = value
        succ!
        item
      else
        stop
      end
    end
  end
end
