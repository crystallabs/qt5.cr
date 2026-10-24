module Qt
  class CborStreamReader
    # Reads the string the reader is at, all chunks of it, and advances past it
    # (like Qt 6's `readAllString`).  An empty string when the reader isn't at
    # a string or on an error, which `#last_error` reports.
    def read_all_string : String
      result = String.build do |io|
        while (chunk = read_string).status.ok?
          io << chunk.data
        end
      end
      result
    end

    # Reads the byte string the reader is at, all chunks of it, and advances
    # past it (like Qt 6's `readAllByteArray`).
    def read_all_byte_array : Bytes
      io = IO::Memory.new
      while (chunk = read_byte_array).status.ok?
        io.write(chunk.data)
      end
      io.to_slice
    end
  end
end
