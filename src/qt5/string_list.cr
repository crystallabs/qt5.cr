module Qt
  # The wrapper of `QList<QString>`, which `QStringList` is an alias of.
  # Methods taking a `QStringList` accept any `Enumerable(String)`, and methods
  # returning one return this.  `Qt::StringList.from(["a", "b"])` builds one.
  alias StringList = Container_QList_QString_

  class Container_QList_QString_
    # The methods `QStringList` adds to `QList<QString>` are in a template
    # specialization bindgen doesn't see, so `ext/string_list_helper.hpp`
    # forwards them.  `#join`, `#select`, `#sort` and `#uniq` of `Enumerable`
    # cover the rest, returning arrays.  The `QRegExp` and `QRegularExpression`
    # overloads wait for those classes to be wrapped.

    # Sorts the list in place.
    def sort!(cs : CaseSensitivity = CaseSensitivity::CaseSensitive) : self
      StringListHelper.sort(self, cs)
      self
    end

    # Removes duplicate entries in place, keeping the first of each.  Returns
    # how many were removed.
    def remove_duplicates!
      StringListHelper.remove_duplicates(self)
    end

    # Returns a new list of the strings containing *str*.
    def filter(str : String, cs : CaseSensitivity = CaseSensitivity::CaseSensitive) : StringList
      StringListHelper.filter(self, str, cs).as(StringList)
    end

    # Replaces *before* with *after* in every string, in place.
    def replace_in_strings!(before : String, after : String, cs : CaseSensitivity = CaseSensitivity::CaseSensitive) : self
      StringListHelper.replace_in_strings(self, before, after, cs)
      self
    end

    # Whether the list contains *str*, compared with the given case
    # sensitivity.  `Enumerable#includes?` compares exactly.
    def includes?(str : String, cs : CaseSensitivity) : Bool
      StringListHelper.contains(self, str, cs)
    end
  end
end
