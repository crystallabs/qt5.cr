// QCborStreamReader::readString and readByteArray return a
// StringResult<T>, a template struct bindgen doesn't instantiate, so they are
// dropped.  These read a whole (possibly chunked) string or byte string and
// advance past it, like Qt 6's readAllString and readAllByteArray; see
// `Qt::CborStreamReader#read_all_string` in src/qt5/cbor.cr.
#include <QtCore/QCborStreamReader>

QString qt5cr_cbor_read_all_string(QCborStreamReader *reader) {
  QString result;
  auto chunk = reader->readString();
  while (chunk.status == QCborStreamReader::Ok) {
    result += chunk.data;
    chunk = reader->readString();
  }
  return result;
}

QByteArray qt5cr_cbor_read_all_byte_array(QCborStreamReader *reader) {
  QByteArray result;
  auto chunk = reader->readByteArray();
  while (chunk.status == QCborStreamReader::Ok) {
    result += chunk.data;
    chunk = reader->readByteArray();
  }
  return result;
}

// Qt 5 declares the QDataStream operators of QCborSimpleType in qcborcommon.h
// but doesn't export them from QtCore, so the binding wouldn't link without
// these definitions, which do what Qt's do.
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
