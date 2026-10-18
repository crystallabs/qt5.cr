// The QXmlStream classes return their names, values and text as QStringRef,
// which the binding doesn't map (the Crystal String maps to QString; a
// QStringRef of a temporary would dangle), so these return them as QString.
// See src/qt5/xml_stream.cr.
#include <QtCore/QXmlStreamReader>
#include <QtCore/QXmlStreamWriter>
#include <QtCore/QDataStream>

#define QT5CR_XML_STRING(klass, prefix, method) \
  QString qt5cr_xml_##prefix##_##method(const klass *object) { return object->method().toString(); }

QT5CR_XML_STRING(QXmlStreamReader, reader, documentVersion)
QT5CR_XML_STRING(QXmlStreamReader, reader, documentEncoding)
QT5CR_XML_STRING(QXmlStreamReader, reader, name)
QT5CR_XML_STRING(QXmlStreamReader, reader, namespaceUri)
QT5CR_XML_STRING(QXmlStreamReader, reader, qualifiedName)
QT5CR_XML_STRING(QXmlStreamReader, reader, prefix)
QT5CR_XML_STRING(QXmlStreamReader, reader, processingInstructionTarget)
QT5CR_XML_STRING(QXmlStreamReader, reader, processingInstructionData)
QT5CR_XML_STRING(QXmlStreamReader, reader, text)
QT5CR_XML_STRING(QXmlStreamReader, reader, dtdName)
QT5CR_XML_STRING(QXmlStreamReader, reader, dtdPublicId)
QT5CR_XML_STRING(QXmlStreamReader, reader, dtdSystemId)
QT5CR_XML_STRING(QXmlStreamAttribute, attribute, namespaceUri)
QT5CR_XML_STRING(QXmlStreamAttribute, attribute, name)
QT5CR_XML_STRING(QXmlStreamAttribute, attribute, qualifiedName)
QT5CR_XML_STRING(QXmlStreamAttribute, attribute, prefix)
QT5CR_XML_STRING(QXmlStreamAttribute, attribute, value)
QT5CR_XML_STRING(QXmlStreamNamespaceDeclaration, namespace_declaration, prefix)
QT5CR_XML_STRING(QXmlStreamNamespaceDeclaration, namespace_declaration, namespaceUri)
QT5CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, name)
QT5CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, systemId)
QT5CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, publicId)
QT5CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, name)
QT5CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, notationName)
QT5CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, systemId)
QT5CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, publicId)
QT5CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, value)

#undef QT5CR_XML_STRING

QString qt5cr_xml_attributes_value(const QXmlStreamAttributes *attributes, const QString &qualifiedName) {
  return attributes->value(qualifiedName).toString();
}

QString qt5cr_xml_attributes_value(const QXmlStreamAttributes *attributes, const QString &namespaceUri, const QString &name) {
  return attributes->value(namespaceUri, name).toString();
}

// QDataStream reads QString and QByteArray through free `operator>>`, which
// take them by non-const reference, which bindgen can't pass the Crystal
// String (a QString by value) by.  See src/qt5/data_stream.cr.
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
