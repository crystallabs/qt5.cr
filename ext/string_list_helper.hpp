// The methods Qt adds to `QList<QString>` as `QStringList` live in the
// template specialization `QListSpecialMethods<QString>`, which bindgen doesn't
// see.  These functions forward to them; `src/qt5/string_list.cr` exposes them
// as methods of the `QList<QString>` wrapper.  Like Qt's own `self()`, the
// list is cast down: `QStringList` adds no data members.

static QStringList &qt5cr_as_string_list(QList<QString> &list) {
  return static_cast<QStringList &>(list);
}

static const QStringList &qt5cr_as_string_list(const QList<QString> &list) {
  return static_cast<const QStringList &>(list);
}

void qt5cr_string_list_sort(QList<QString> &list, Qt::CaseSensitivity cs) {
  qt5cr_as_string_list(list).sort(cs);
}

int qt5cr_string_list_removeDuplicates(QList<QString> &list) {
  return qt5cr_as_string_list(list).removeDuplicates();
}

QStringList qt5cr_string_list_filter(const QList<QString> &list, const QString &str, Qt::CaseSensitivity cs) {
  return qt5cr_as_string_list(list).filter(str, cs);
}

void qt5cr_string_list_replaceInStrings(QList<QString> &list, const QString &before, const QString &after, Qt::CaseSensitivity cs) {
  qt5cr_as_string_list(list).replaceInStrings(before, after, cs);
}

bool qt5cr_string_list_contains(const QList<QString> &list, const QString &str, Qt::CaseSensitivity cs) {
  return qt5cr_as_string_list(list).contains(str, cs);
}
