require "../spec_helper"

# The `const char *` names of the meta-object system are `UInt8*`, read with
# `String.new`.
describe Qt::MetaObject do
  it "describes a class" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    String.new(meta.class_name).should eq("QPushButton")
    String.new(meta.super_class.not_nil!.class_name).should eq("QAbstractButton")
    # `static_meta_object` is a copy of the class's QMetaObject, which
    # `inherits` doesn't compare equal to the one an object refers to.
    widget_meta = Qt::Widget.new.meta_object.not_nil!
    meta.inherits(widget_meta).should be_true
    widget_meta.inherits(meta).should be_false
    String.new(Qt::Widget.static_meta_object.class_name).should eq("QWidget")
    meta.property_count.should be > meta.property_offset
    meta.method_count.should be > 0
    String.new(Qt::MetaObject.normalized_signature("clicked( bool )".to_unsafe)).should eq("clicked(bool)")
    String.new(Qt::MetaObject.normalized_type("const QString &".to_unsafe)).should eq("QString")
    meta.cast(button).should eq(button)
    meta.cast(Qt::Object.new).should be_nil
  end

  it "reads and writes properties" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    index = meta.index_of_property("text".to_unsafe)
    index.should be >= 0
    property = meta.property(index)
    property.valid?.should be_true
    String.new(property.name).should eq("text")
    String.new(property.type_name).should eq("QString")
    property.type.should eq(Qt::VariantType::String)
    property.user_type.should eq(Qt::MetaType::Type::QString.to_i)
    property.readable?.should be_true
    property.writable?.should be_true
    property.read(button).to(String).should eq("ok")
    property.write(button, Qt.variant("changed")).should be_true
    button.text.should eq("changed")
    String.new(meta.user_property.name).should eq("checked")
    meta.index_of_property("nope".to_unsafe).should eq(-1)
  end

  it "lists methods and invokes them" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    index = meta.index_of_signal("clicked(bool)".to_unsafe)
    index.should be >= 0
    method = meta.method(index)
    method.method_type.should eq(Qt::MetaMethod::MethodType::Signal)
    method.access.should eq(Qt::MetaMethod::Access::Public)
    String.new(method.name).should eq("clicked")
    String.new(method.method_signature).should eq("clicked(bool)")
    method.parameter_count.should eq(1)
    String.new(method.parameter_types.first).should eq("bool")
    method.parameter_type(0).should eq(Qt::MetaType::Type::Bool.to_i)
    method.parameter_names.map { |n| String.new(n) }.should eq(["checked"])
    method.return_type.should eq(Qt::MetaType::Type::Void.to_i)
    String.new(method.enclosing_meta_object.not_nil!.class_name).should eq("QAbstractButton")
    meta.method(meta.index_of_slot("click()".to_unsafe)).method_type.should eq(Qt::MetaMethod::MethodType::Slot)
    meta.index_of_method("nope()".to_unsafe).should eq(-1)

    clicked = false
    button.on_clicked { clicked = true }
    Qt::MetaObject.invoke_method(button, "click").should be_true
    clicked.should be_true
    Qt::MetaObject.invoke_method(button, "nope").should be_false
  end

  it "describes enums" do
    meta = Qt::Frame.static_meta_object
    index = meta.index_of_enumerator("Shape".to_unsafe)
    index.should be >= 0
    shape = meta.enumerator(index)
    shape.valid?.should be_true
    String.new(shape.name).should eq("Shape")
    String.new(shape.scope).should eq("QFrame")
    shape.flag?.should be_false
    shape.key_count.should eq(Qt::Frame::Shape.values.size)
    shape.key_to_value("Box".to_unsafe).should eq({Qt::Frame::Shape::Box.to_i, true}) # With the `bool *ok`
    String.new(shape.value_to_key(Qt::Frame::Shape::Panel.to_i)).should eq("Panel")
    (0...shape.key_count).map { |i| String.new(shape.key(i)) }.should contain("NoFrame")
    meta.class_info_count.should eq(0)
  end
end

describe Qt::MetaType do
  it "describes types" do
    int = Qt::MetaType.new(Qt::MetaType::Type::Int.to_i)
    int.valid?.should be_true
    String.new(int.name).should eq("int")
    int.size_of.should eq(4)
    int.flags.should_not eq(Qt::MetaType::TypeFlags::None)
    string = Qt::MetaType.type("QString".to_slice)
    string.should eq(Qt::MetaType::Type::QString.to_i)
    (int == Qt::MetaType.new(string)).should be_false
    String.new(Qt::MetaType.type_name(string)).should eq("QString")
    Qt::MetaType.type("NoSuchType".to_slice).should eq(Qt::MetaType::Type::UnknownType.to_i)
    Qt::MetaType.new.valid?.should be_false
    String.new(Qt::MetaType.meta_object_for_type(Qt::MetaType::Type::QObjectStar.to_i).not_nil!.class_name).should eq("QObject")
  end
end

describe Qt::ObjectCleanupHandler do
  it "deletes the objects it holds" do
    handler = Qt::ObjectCleanupHandler.new
    handler.empty?.should be_true
    object = Qt::Object.new
    handler.add(object).should eq(object)
    handler.empty?.should be_false
    handler.remove(object)
    handler.empty?.should be_true
    handler.add(Qt::Object.new)
    handler.clear
    handler.empty?.should be_true
  end
end

describe Qt::ByteArrayMatcher do
  it "finds a pattern" do
    matcher = Qt::ByteArrayMatcher.new("needle".to_slice)
    String.new(matcher.pattern).should eq("needle")
    matcher.index_in("hay needle stack".to_slice).should eq(4)
    matcher.index_in("hay".to_slice).should eq(-1)
    matcher.index_in("needle needle".to_slice, 1).should eq(7)

    strings = Qt::StringMatcher.new("Needle", Qt::CaseSensitivity::CaseInsensitive)
    strings.pattern.should eq("Needle")
    strings.index_in("hay needle stack").should eq(4)
    strings.case_sensitivity = Qt::CaseSensitivity::CaseSensitive
    strings.index_in("hay needle stack").should eq(-1)
  end
end

describe Qt::TextEncoder do
  it "converts with a codec" do
    codec = Qt::TextCodec.codec_for_name("UTF-16BE".to_slice).not_nil!
    encoder = Qt::TextEncoder.new(codec, Qt::TextCodec::ConversionFlags::IgnoreHeader)
    bytes = encoder.from_unicode("hi")
    bytes.should eq(Bytes[0, 0x68, 0, 0x69])
    encoder.has_failure?.should be_false
    decoder = Qt::TextDecoder.new(codec)
    decoder.to_unicode(bytes).should eq("hi")
    decoder.to_unicode(Bytes[0]).should eq("") # Half a character
    decoder.needs_more_data.should be_true
    decoder.to_unicode(Bytes[0x21]).should eq("!")
  end
end
