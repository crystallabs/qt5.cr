module Qt
  # bindgen splits the default `parent` argument of the pure virtual methods of
  # `QAbstractItemModel` into a separate overload, which stays abstract in each
  # abstract model class re-declaring it (the `Impl` classes get it from C++).
  # A Crystal subclass only implements what its C++ counterpart would, the
  # overloads taking the parent, so these forward to them.
  {% for klass in %w[AbstractItemModel AbstractListModel AbstractTableModel AbstractProxyModel] %}
    abstract class {{ klass.id }}
      def row_count : Int32
        row_count(ModelIndex.new)
      end

      def column_count : Int32
        column_count(ModelIndex.new)
      end
    end
  {% end %}

  # `QAbstractListModel` implements `index` itself, with the default argument.
  {% for klass in %w[AbstractItemModel AbstractProxyModel] %}
    abstract class {{ klass.id }}
      def index(row : Int32, column : Int32) : ModelIndex
        index(row, column, ModelIndex.new)
      end
    end
  {% end %}
end
