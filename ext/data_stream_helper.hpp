// QDataStream reads QString and QByteArray through free `operator>>`, which
// take them by non-const reference, which bindgen can't pass the Crystal
// String (a QString by value) by.  See src/qt5/data_stream.cr.
#include <QtCore/QDataStream>

QString qt5cr_data_stream_read_string(QDataStream *stream) {
  QString string;
  *stream >> string;
  return string;
}

QByteArray qt5cr_data_stream_read_bytes(QDataStream *stream) {
  QByteArray bytes;
  *stream >> bytes;
  return bytes;
}
