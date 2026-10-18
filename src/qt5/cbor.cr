module Qt
  # `QCborStreamReader::readString` and `readByteArray` return a
  # `StringResult<T>` bindgen doesn't instantiate, so the helpers in
  # `ext/cbor_helper.hpp` read a whole string instead, like Qt 6's
  # `readAllString` and `readAllByteArray`.
  class CborStreamReader
    # Reads the string the reader is at, all chunks of it, and advances past it.
    # An empty string when the reader isn't at a string or on an error, which
    # `#last_error` reports.
    def read_all_string : String
      Qt.qt5cr_cbor_read_all_string(self)
    end

    # Reads the byte string the reader is at, all chunks of it, and advances
    # past it.
    def read_all_byte_array : Bytes
      Qt.qt5cr_cbor_read_all_byte_array(self)
    end
  end

  class CborStreamWriter
    # Appends *string* as a text string.  Qt 5's overloads take a
    # `QStringView` or `QLatin1String`, which aren't wrapped.
    def append(string : String) : Void
      append_text_string(string.to_unsafe, string.bytesize.to_i64)
    end
  end
end
