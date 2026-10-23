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

    # Reads a value written by `#<<`: a number, a `Bool`, or a copied
    # structure like `Qt::Point`, which `>>` takes by pointer.
    def read(type : T.class) : T forall T
      value = uninitialized T
      self >> pointerof(value)
      value
    end

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
