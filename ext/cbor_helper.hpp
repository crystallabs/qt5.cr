// Qt 5 declares the QDataStream operators of QCborSimpleType in qcborcommon.h
// but doesn't export them from QtCore, so the binding wouldn't link without
// these definitions, which do what Qt's do.
#include <QtCore/QCborStreamReader>
#include <QtCore/QDataStream>

QDataStream &operator<<(QDataStream &ds, QCborSimpleType st) {
  return ds << quint8(st);
}

QDataStream &operator>>(QDataStream &ds, QCborSimpleType &st) {
  quint8 v;
  ds >> v;
  st = QCborSimpleType(v);
  return ds;
}
