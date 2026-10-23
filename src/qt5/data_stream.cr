module Qt
  # Qt reads `QString` and `QByteArray` through free `operator>>`, which take
  # them by non-const reference, which bindgen can't pass a `String` by, so
  # these come from `ext/data_stream_helper.hpp`.  The numbers are read through
  # `#read`:
  #
  # ```
  # stream << 42 << "text"
  # stream.read(Int32)  # => 42
  # stream.read(String) # => "text"
  # ```
  class DataStream
    # Reads a string written by `#<<`.
    def read_string : String
      Qt.qt5cr_data_stream_read_string(self)
    end

    # Reads the bytes written by `#<<`.
    def read_bytes : Bytes
      Qt.qt5cr_data_stream_read_bytes(self)
    end

    {% for type in [Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64] %}
      # Reads a `{{type}}` written by `#<<`.
      def read(type : {{type}}.class) : {{type}}
        value = uninitialized {{type}}
        self >> pointerof(value)
        value
      end
    {% end %}

    # Reads a `String` written by `#<<`.
    def read(type : String.class) : String
      read_string
    end

    # Reads the `Bytes` written by `#<<`.
    def read(type : Bytes.class) : Bytes
      read_bytes
    end
  end
end
