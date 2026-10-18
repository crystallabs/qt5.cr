module Qt
  # bindgen expands the default `parent` argument of the pure virtual methods
  # of `QAbstractItemModel` into separate abstract overloads, but the abstract
  # models deriving from it, and their `Impl` classes, only get the overload
  # copied from the C++ declaration ("abstract `def
  # Qt::AbstractItemModel#index(row : Int32, column : Int32)` must be
  # implemented by Qt::AbstractProxyModelImpl").  `QAbstractListModel` and
  # `QAbstractTableModel` also re-declare `parent()` and `columnCount()` as
  # private, which drops them.  These are Qt's defaults, so a Crystal subclass
  # only implements what its C++ counterpart would.
  abstract class AbstractListModel
    def index(row : Int32, column : Int32) : ModelIndex
      index(row, column, ModelIndex.new)
    end

    def row_count : Int32
      row_count(ModelIndex.new)
    end

    # A list has one column, and no children below its items.
    def column_count(parent : ModelIndex = ModelIndex.new) : Int32
      parent.valid? ? 0 : 1
    end

    def parent(child : ModelIndex) : ModelIndex
      ModelIndex.new
    end
  end

  abstract class AbstractTableModel
    def row_count : Int32
      row_count(ModelIndex.new)
    end

    def column_count : Int32
      column_count(ModelIndex.new)
    end

    # A table has no children below its items.
    def parent(child : ModelIndex) : ModelIndex
      ModelIndex.new
    end
  end

  abstract class AbstractProxyModel
    def index(row : Int32, column : Int32) : ModelIndex
      index(row, column, ModelIndex.new)
    end

    def row_count : Int32
      row_count(ModelIndex.new)
    end

    def column_count : Int32
      column_count(ModelIndex.new)
    end
  end
end
