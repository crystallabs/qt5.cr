require "../spec_helper"

# `Qt::Variant` exchanges the types Qt knows in their native `QVariant` form,
# anything else as the Crystal value.
class VariantSpecObject
  property name : String

  def initialize(@name)
  end
end

private def round_trip(value)
  model = Qt::StandardItemModel.new(1, 1)
  index = model.index(0, 0)
  model.set_data(index, Qt.variant(value)).should be_true
  model.data(index)
end

describe "Qt::Variant through Qt" do
  it "round trips the native types" do
    round_trip("x").to(String).should eq("x")
    round_trip("").to(String).should eq("")
    round_trip("ünïcödé ✓").to(String).should eq("ünïcödé ✓")
    round_trip(123).to(Int32).should eq(123)
    round_trip(-123).to(Int32).should eq(-123)
    round_trip(123u32).to(UInt32).should eq(123u32)
    round_trip(1i64 << 40).to(Int64).should eq(1i64 << 40)
    round_trip(UInt64::MAX).to(UInt64).should eq(UInt64::MAX)
    round_trip(1.5f32).to(Float32).should eq(1.5f32)
    round_trip(2.25).to(Float64).should eq(2.25)
    round_trip(true).to(Bool).should be_true
    round_trip(false).to(Bool).should be_false
    round_trip('é').to(Char).should eq('é')
    round_trip(%w[a b c]).to(Array(String)).should eq(%w[a b c])
    round_trip([] of String).to(Array(String)).should eq([] of String)
    round_trip(Bytes[0, 1, 255]).to(Bytes).should eq(Bytes[0, 1, 255])
    round_trip(Qt::Point.new(1, 2)).to(Qt::Point).should eq(Qt::Point.new(1, 2))
    round_trip(Qt::PointF.new(1.5, 2.5)).to(Qt::PointF).should eq(Qt::PointF.new(1.5, 2.5))
    round_trip(Qt::Size.new(3, 4)).to(Qt::Size).should eq(Qt::Size.new(3, 4))
    round_trip(Qt::SizeF.new(3.5, 4.5)).to(Qt::SizeF).should eq(Qt::SizeF.new(3.5, 4.5))
    round_trip(Qt::Rect.new(1, 2, 3, 4)).to(Qt::Rect).should eq(Qt::Rect.new(1, 2, 3, 4))
    round_trip(Qt::RectF.new(1.5, 2.5, 3.5, 4.5)).to(Qt::RectF).should eq(Qt::RectF.new(1.5, 2.5, 3.5, 4.5))
  end

  it "round trips nil" do
    variant = round_trip(nil)
    variant.is_nil?.should be_true
    variant.to?(String).should be_nil
  end

  it "round trips a wrapped Qt::StringList as Array(String)" do
    list = Qt::StringList.from(["x", "y"])
    round_trip(list).to(Array(String)).should eq(["x", "y"])
  end

  it "passes non-BMP characters as a string" do
    round_trip('😀').to(String).should eq("😀")
  end

  it "round trips a Crystal object" do
    object = VariantSpecObject.new("mine")
    variant = round_trip(object)
    variant.is?(VariantSpecObject).should be_true
    variant.to(VariantSpecObject).should be(object)
    variant.to?(String).should be_nil

    round_trip({1, "two"}).to(Tuple(Int32, String)).should eq({1, "two"})
  end

  it "tags the native types for Qt" do
    Qt.variant("x").to_unsafe.type_id.should eq(Qt::Variant::Tag::String.value)
    Qt.variant(1).to_unsafe.type_id.should eq(Qt::Variant::Tag::Int32.value)
    Qt.variant(%w[a]).to_unsafe.type_id.should eq(Qt::Variant::Tag::StringList.value)
    Qt.variant(nil).to_unsafe.type_id.should eq(0)
    Qt.variant({1, 2}).to_unsafe.type_id.should eq({1, 2}.crystal_type_id)

    # Only Qt sees the tagged form: the variant itself holds the Crystal value.
    Qt.variant("x").type_id.should eq(String.crystal_instance_type_id)
    Qt::Variant.new(Qt.variant("x")).to(String).should eq("x")
  end

  it "unpacks a value Qt produced" do
    model = Qt::StandardItemModel.new(1, 2)
    model.set_header_data(1, Qt::Orientation::Horizontal, Qt.variant("Name")).should be_true
    model.header_data(1, Qt::Orientation::Horizontal).to(String).should eq("Name")
    # Without a header set, Qt answers with the section number.
    model.header_data(0, Qt::Orientation::Vertical).to(Int32).should eq(1)
    model.header_data(0, Qt::Orientation::Horizontal, 1).is_nil?.should be_true # Qt::DecorationRole

    object = Qt::Object.new
    object.set_property("spec".to_unsafe, Qt.variant("value")) # Dynamic: Qt returns false
    object.property("spec".to_unsafe).to(String).should eq("value")
    object.property("missing".to_unsafe).is_nil?.should be_true

    widget = Qt::Widget.new
    widget.resize(30, 40)
    widget.property("enabled".to_unsafe).to(Bool).should be_true
    widget.property("size".to_unsafe).to(Qt::Size).should eq(Qt::Size.new(30, 40))
    widget.property("windowTitle".to_unsafe).to(String).should eq("") # A null QString, not nil
  end

  it "unpacks a Qt type without a mapping as unknown" do
    variant = Qt::Widget.new.property("font".to_unsafe) # A QFont
    variant.is_nil?.should be_false
    variant.is?(String).should be_false
    variant.to?(String).should be_nil
    variant.type_id.should eq(Qt::Variant::Tag::Unknown.value)
    expect_raises(TypeCastError) { variant.to(String) }

    # Qt gets the value back out of it.
    font = Qt::Font.new
    font.point_size = 42
    widget = Qt::Widget.new
    widget.font = font
    variant = round_trip(widget.property("font".to_unsafe))
    variant.type_id.should eq(Qt::Variant::Tag::Unknown.value)
    other = Qt::Widget.new
    other.set_property("font".to_unsafe, variant).should be_true
    other.font.point_size.should eq(42)
  end

  it "survives garbage collection of the exchanged data" do
    model = Qt::StandardItemModel.new(1, 1)
    index = model.index(0, 0)
    2000.times do |i|
      model.set_data(index, Qt.variant("string #{i}")).should be_true
      GC.collect if i % 100 == 0
      model.data(index).to(String).should eq("string #{i}")
      model.set_data(index, Qt.variant(["a#{i}", "b"])).should be_true
      model.set_data(index, Qt.variant(Qt::RectF.new(i, 1, 2, 3))).should be_true
      GC.collect if i % 100 == 50
      model.data(index).to(Qt::RectF).should eq(Qt::RectF.new(i, 1, 2, 3))
      model.set_data(index, Qt.variant(Bytes[i.to_u8!, 1])).should be_true
      model.data(index).to(Bytes).should eq(Bytes[i.to_u8!, 1])
    end
  end
end
