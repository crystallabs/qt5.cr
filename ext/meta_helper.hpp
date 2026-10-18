// QMetaObject::invokeMethod and QMetaMethod::invoke take their arguments as
// QGenericArgument (a type name and a void pointer) or as templates, neither
// of which Crystal can fill, so those overloads are dropped.  This invokes a
// method without arguments by name, see `Qt::MetaObject.invoke_method` in
// src/qt5/meta_object.cr.
#include <QtCore/QMetaObject>
#include <QtCore/QObject>

bool qt5cr_invoke_method(QObject *object, const char *member, Qt::ConnectionType type) {
  return QMetaObject::invokeMethod(object, member, type);
}
