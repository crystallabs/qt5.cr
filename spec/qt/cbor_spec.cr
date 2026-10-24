require "../spec_helper"

describe Qt::CborValue do
  it "holds values" do
    Qt::CborValue.new.undefined?.should be_true
    Qt::CborValue.new(Qt::CborValue::Type::Null).null?.should be_true
    Qt::CborValue.new(true).to_bool.should be_true
    value = Qt::CborValue.new(42_i64)
    value.integer?.should be_true
    value.type.should eq(Qt::CborValue::Type::Integer)
    value.to_integer.should eq(42)
    Qt::CborValue.new(1.5).to_double.should eq(1.5)
    Qt::CborValue.new("text").to_string.should eq("text")
    Qt::CborValue.new("bytes".to_slice).to_byte_array.should eq("bytes".to_slice)
    Qt::CborValue.new(Qt::Url.new("http://example.org")).to_url.to_string.should eq("http://example.org")
    Qt::CborValue.new(Qt::CborSimpleType::Null).null?.should be_true
    tagged = Qt::CborValue.new(Qt::CborKnownTags::Url, Qt::CborValue.new("http://example.org"))
    tagged.tag?.should be_true
    tagged.tagged_value.to_string.should eq("http://example.org")
    tagged.tag.should eq(Qt::CborKnownTags::Url.to_u64)
    Qt::CborValue.new(32_u64, Qt::CborValue.new("x")).should eq(Qt::CborValue.new(Qt::CborKnownTags::Url, Qt::CborValue.new("x")))
    (value < Qt::CborValue.new(43_i64)).should be_true
    value.compare(Qt::CborValue.new(42_i64)).should eq(0)
    value.to_variant.to(Int64).should eq(42)
    Qt::CborValue.from_variant(Qt.variant("v")).to_string.should eq("v")
    Qt::CborValue.from_json_value(Qt::JsonValue.new(2)).to_integer.should eq(2)
    value.to_json_value.to_int.should eq(42)
  end

  it "encodes and decodes" do
    map = Qt::CborMap.new
    map.insert("name", Qt::CborValue.new("qt5"))
    map.insert(1_i64, Qt::CborValue.new(2_i64))
    map.size.should eq(2)
    map.contains("name").should be_true
    map["name"].to_string.should eq("qt5")
    map.value(1_i64).to_integer.should eq(2)
    map.keys.map(&.to_integer(0)).should contain(1)
    value = map.to_cbor_value
    value.map?.should be_true
    value["name"].to_string.should eq("qt5")
    bytes = value.to_cbor
    bytes.size.should be > 0
    error = Qt::CborParserError.new
    decoded = Qt::CborValue.from_cbor(bytes, error)
    error.error.c.should eq(Qt::CborError::Code::NoError)
    error.error_string.should eq("")
    decoded.should eq(value)
    decoded.to_map["name"].to_string.should eq("qt5")
    Qt::CborValue.from_cbor(Bytes[0xff, 0xff], error).invalid?.should be_true
    error.error.c.should_not eq(Qt::CborError::Code::NoError)
    error.error_string.should_not eq("")
    value.to_diagnostic_notation.should contain("\"qt5\"")
    map.to_json_object["name"].to_string.should eq("qt5")
    map.to_variant_map["name"].to(String).should eq("qt5")
    map.take("name").to_string.should eq("qt5")
    map.contains("name").should be_false
    map.remove(1_i64)
    map.empty?.should be_true
    Qt::CborMap.from_json_object(Qt::JsonObject.new).empty?.should be_true
  end

  it "iterates a map" do
    map = Qt::CborMap.new
    iterator = map.insert("a", Qt::CborValue.new(1_i64))
    iterator.key.to_string.should eq("a")
    iterator.value.to_integer.should eq(1)
    iterator.value.assign!(Qt::CborValue.new(3_i64))
    map["a"].to_integer.should eq(3)
    map.insert({Qt::CborValue.new("b"), Qt::CborValue.new(2_i64)})
    (map.end - map.begin).should eq(2)
    map.find("b").value.to_integer.should eq(2)
    map.erase(map.find("a"))
    map.size.should eq(1)
  end

  it "holds arrays" do
    array = Qt::CborArray.new
    array.append(Qt::CborValue.new(1_i64))
    array << Qt::CborValue.new("two")
    array.insert(0, Qt::CborValue.new(0_i64))
    array.size.should eq(3)
    array[0].to_integer.should eq(0)
    array.at(2).to_string.should eq("two")
    array.first.to_integer.should eq(0)
    array.contains(Qt::CborValue.new("two")).should be_true
    array.to_variant_list.map(&.to?(Int64)).should eq([0, 1, nil])
    array.to_json_array.size.should eq(3)
    array.take_first.to_integer.should eq(0)
    array.remove_last
    array.size.should eq(1)
    Qt::CborArray.from_string_list(["x", "y"]).last.to_string.should eq("y")
    Qt::CborValue.new(array).array?.should be_true
  end

  it "streams" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly)
    writer = Qt::CborStreamWriter.new(buffer)
    writer.start_map(2_u64)
    writer.append("n")
    writer.append(7_i64) # Int64: the UInt64 overload appends a QCborTag
    writer.append("s")
    writer.append("text")
    writer.end_map.should be_true
    buffer.close
    bytes = buffer.data
    bytes.size.should be > 0

    reader = Qt::CborStreamReader.new(bytes)
    reader.map?.should be_true
    reader.length_known?.should be_true
    reader.length.should eq(2)
    reader.enter_container.should be_true
    reader.string?.should be_true
    chunk = reader.read_string
    chunk.status.ok?.should be_true
    chunk.data.should eq("n")
    reader.read_string.status.end_of_string?.should be_true
    reader.unsigned_integer?.should be_true
    reader.to_integer.should eq(7)
    reader.next.should be_true
    reader.read_all_string.should eq("s")
    reader.read_all_string.should eq("text")
    reader.has_next?.should be_false
    reader.leave_container.should be_true
    reader.last_error.c.should eq(Qt::CborError::Code::NoError)

    Qt::CborValue.from_cbor(bytes).to_map["n"].to_integer.should eq(7)
    Qt::CborValue.from_cbor(Qt::CborStreamReader.new(bytes))["s"].to_string.should eq("text")
    Qt::CborStreamReader.new(Qt::CborValue.new("bytes".to_slice).to_cbor).read_all_byte_array.should eq("bytes".to_slice)
  end
end
