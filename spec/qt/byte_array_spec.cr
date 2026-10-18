require "../spec_helper"

# `QByteArray` maps to `Bytes`, copied in both directions.
describe "QByteArray" do
  it "is returned from Qt" do
    Qt::Url.to_percent_encoding("a b/ü").should eq("a%20b%2F%C3%BC".to_slice)
    Qt::Url.from_percent_encoding("a%20b%2F%C3%BC".to_slice).should eq("a b/ü")
    Qt::Url.new("http://example.com/ü?q=1").to_encoded.should eq("http://example.com/%C3%BC?q=1".to_slice)
    Qt::Url.from_encoded("http://example.com/%C3%BC".to_slice).path.should eq("/ü")
    Qt::Url.new("").to_encoded.should eq(Bytes.empty)
  end

  it "is passed to and returned from Qt" do
    data = Bytes[0, 1, 2, 255, 128, 0, 7]
    mime = Qt::MimeData.new
    mime.set_data("application/x-spec", data)
    mime.has_format("application/x-spec").should be_true
    mime.data("application/x-spec").should eq(data)
    mime.data("application/x-spec").should_not be(data) # A copy
    mime.data("text/plain").should eq(Bytes.empty)
    mime.set_data("text/plain", "text".to_slice)
    mime.text.should eq("text")

    widget = Qt::Widget.new
    widget.resize(123, 45)
    geometry = widget.save_geometry
    geometry.empty?.should be_false
    widget.resize(10, 10)
    widget.restore_geometry(geometry).should be_true
    widget.size.should eq(Qt::Size.new(123, 45))
    widget.restore_geometry(Bytes.empty).should be_false
  end

  it "is listed in a QList<QByteArray>" do
    object = Qt::Object.new
    object.set_property("spec".to_unsafe, Qt.variant(1))
    object.dynamic_property_names.map { |name| String.new(name) }.should eq(["spec"])
  end
end
