module Qt
  # The QXmlStream classes return their names, values and text as
  # `QStringRef`, which the binding doesn't map, so these are the helpers of
  # `ext/xml_helper.hpp`, which return them as `String`.
  class XmlStreamReader
    {% for method in %w[document_version document_encoding name namespace_uri qualified_name prefix processing_instruction_target processing_instruction_data text dtd_name dtd_public_id dtd_system_id] %}
      def {{method.id}} : String
        Qt.qt5cr_xml_reader_{{method.id}}(self)
      end
    {% end %}
  end

  class XmlStreamAttribute
    {% for method in %w[namespace_uri name qualified_name prefix value] %}
      def {{method.id}} : String
        Qt.qt5cr_xml_attribute_{{method.id}}(self)
      end
    {% end %}
  end

  # The attributes of the current element, see `XmlStreamReader#attributes`:
  # a list of `XmlStreamAttribute`.
  class XmlStreamAttributes
    # Returns the value of the attribute *qualified_name*, or "" if there is none.
    def value(qualified_name : String) : String
      Qt.qt5cr_xml_attributes_value(self, qualified_name)
    end

    # Returns the value of the attribute *name* in *namespace_uri*, or "".
    def value(namespace_uri : String, name : String) : String
      Qt.qt5cr_xml_attributes_value(self, namespace_uri, name)
    end
  end

  class XmlStreamNamespaceDeclaration
    {% for method in %w[prefix namespace_uri] %}
      def {{method.id}} : String
        Qt.qt5cr_xml_namespace_declaration_{{method.id}}(self)
      end
    {% end %}
  end

  class XmlStreamNotationDeclaration
    {% for method in %w[name system_id public_id] %}
      def {{method.id}} : String
        Qt.qt5cr_xml_notation_declaration_{{method.id}}(self)
      end
    {% end %}
  end

  class XmlStreamEntityDeclaration
    {% for method in %w[name notation_name system_id public_id value] %}
      def {{method.id}} : String
        Qt.qt5cr_xml_entity_declaration_{{method.id}}(self)
      end
    {% end %}
  end
end
