require "../spec_helper"
require "openssl/hmac"

# The event, device, input and data classes.

# Records the input events it receives.
private class RecordingWidget < Qt::Widget
  getter wheel_deltas = [] of Int32
  getter event_types = [] of Qt::Event::Type
  getter context_menus = [] of Qt::ContextMenuEvent::Reason
  getter timer_ticks = 0
  property loop : Qt::EventLoop?

  def event(event : Qt::Event) : Bool
    @event_types << event.type
    superclass.event(event)
  end

  def wheel_event(event : Qt::WheelEvent) : Void
    @wheel_deltas << event.angle_delta.y
    event.accept
  end

  def context_menu_event(event : Qt::ContextMenuEvent) : Void
    @context_menus << event.reason
  end

  def timer_event(event : Qt::TimerEvent) : Void
    @timer_ticks += 1
    @loop.try(&.quit) if @timer_ticks == 2
  end
end

describe "input events" do
  it "are delivered to a widget's overrides" do
    widget = RecordingWidget.new
    widget.resize(50, 50)
    widget.set_attribute(Qt::Widget::Attribute::AcceptTouchEvents, true)
    widget.show

    wheel = Qt::WheelEvent.new(Qt::PointF.new(5.0, 5.0), Qt::PointF.new(5.0, 5.0), Qt::Point.new(0, 0), Qt::Point.new(0, 120),
      Qt::MouseButtons::NoButton, Qt::KeyboardModifiers::NoModifier, Qt::ScrollPhase::NoScrollPhase, false)
    wheel.angle_delta.should eq(Qt::Point.new(0, 120))
    wheel.phase.should eq(Qt::ScrollPhase::NoScrollPhase)
    wheel.inverted.should be_false
    wheel.position.should eq(Qt::PointF.new(5.0, 5.0))
    Qt::Application.send_event(widget, wheel).should be_true
    widget.wheel_deltas.should eq([120])

    hover = Qt::HoverEvent.new(Qt::Event::Type::HoverMove, Qt::PointF.new(3.0, 4.0), Qt::PointF.new(1.0, 1.0))
    hover.old_pos_f.should eq(Qt::PointF.new(1.0, 1.0))
    hover.pos_f.should eq(Qt::PointF.new(3.0, 4.0))
    hover.pos.should eq(Qt::Point.new(3, 4))
    Qt::Application.send_event(widget, hover)
    widget.event_types.should contain(Qt::Event::Type::HoverMove)

    device = Qt::TouchDevice.new
    device.name = "spec"
    device.type = Qt::TouchDevice::DeviceType::TouchScreen
    device.capabilities = Qt::TouchDevice::Capabilities::Position
    device.maximum_touch_points = 2
    device.maximum_touch_points.should eq(2)
    device.capabilities.should eq(Qt::TouchDevice::Capabilities::Position)
    point = Qt::TouchPoint.new(1)
    point.state = Qt::TouchPointStates::TouchPointPressed
    point.scene_pos = Qt::PointF.new(2.0, 3.0)
    point.screen_pos = Qt::PointF.new(12.0, 13.0)
    point.id.should eq(1)
    point.state.should eq(Qt::TouchPointState::TouchPointPressed)
    point.scene_pos.should eq(Qt::PointF.new(2.0, 3.0))
    point.screen_pos.should eq(Qt::PointF.new(12.0, 13.0))
    touch = Qt::TouchEvent.new(Qt::Event::Type::TouchBegin, device, Qt::KeyboardModifiers::NoModifier, Qt::TouchPointStates::TouchPointPressed, [point])
    touch.touch_points.size.should eq(1)
    touch.touch_points.first.id.should eq(1)
    touch.touch_point_states.should eq(Qt::TouchPointStates::TouchPointPressed)
    touch.device.not_nil!.name.should eq("spec")
    Qt::Application.send_event(widget, touch)
    widget.event_types.should contain(Qt::Event::Type::TouchBegin)

    menu = Qt::ContextMenuEvent.new(Qt::ContextMenuEvent::Reason::Keyboard, Qt::Point.new(1, 1), Qt::Point.new(2, 2))
    menu.pos.should eq(Qt::Point.new(1, 1))
    menu.global_pos.should eq(Qt::Point.new(2, 2))
    Qt::Application.send_event(widget, menu)
    widget.context_menus.should eq([Qt::ContextMenuEvent::Reason::Keyboard])

    child = Qt::Object.new
    child_event = Qt::ChildEvent.new(Qt::Event::Type::ChildAdded, child)
    child_event.child.not_nil!.to_unsafe.should eq(child.to_unsafe)
    child_event.added.should be_true
    Qt::WindowStateChangeEvent.new(Qt::WindowStates::WindowMinimized).old_state.should eq(Qt::WindowStates::WindowMinimized)
    gesture = Qt::NativeGestureEvent.new(Qt::NativeGestureType::ZoomNativeGesture, device, Qt::PointF.new(1.0, 1.0), Qt::PointF.new(2.0, 2.0), Qt::PointF.new(3.0, 3.0), 0.5, 0, 0)
    gesture.gesture_type.should eq(Qt::NativeGestureType::ZoomNativeGesture)
    gesture.value.should eq(0.5)
    gesture.local_pos.should eq(Qt::PointF.new(1.0, 1.0))
  end

  it "come from input devices" do
    id = Qt::PointingDeviceUniqueId.from_numeric_id(42)
    id.valid?.should be_true
    id.numeric_id.should eq(42)
    Qt::PointingDeviceUniqueId.new.valid?.should be_false

    input_method = Qt::GuiApplication.input_method.not_nil!
    input_method.visible?.should be_false
    input_method.keyboard_rectangle.should be_a(Qt::RectF)
    input_method.locale.should be_a(Qt::Locale)
  end

  it "describe gestures" do
    pan = Qt::PanGesture.new
    pan.gesture_type.should eq(Qt::GestureType::PanGesture)
    pan.offset = Qt::PointF.new(3.0, 4.0)
    pan.offset.should eq(Qt::PointF.new(3.0, 4.0))
    pinch = Qt::PinchGesture.new
    pinch.total_scale_factor = 2.0
    pinch.total_scale_factor.should eq(2.0)
    pinch.change_flags = Qt::PinchGesture::ChangeFlags::ScaleFactorChanged
    pinch.change_flags.should eq(Qt::PinchGesture::ChangeFlags::ScaleFactorChanged)
    swipe = Qt::SwipeGesture.new
    swipe.swipe_angle = 90.0
    swipe.vertical_direction.should eq(Qt::SwipeGesture::SwipeDirection::Up)
    tap = Qt::TapGesture.new
    tap.position = Qt::PointF.new(1.0, 2.0)
    tap.position.should eq(Qt::PointF.new(1.0, 2.0))
    Qt::TapAndHoldGesture.timeout = 600
    Qt::TapAndHoldGesture.timeout.should eq(600)
  end
end

describe Qt::InputMethodEvent do
  it "carries preedit attributes" do
    cursor = Qt::InputMethodEventAttribute.new(Qt::InputMethodEvent::AttributeType::Cursor, 2, 1, Qt.variant(7))
    cursor.start.should eq(2)
    cursor.length = 0
    cursor.length.should eq(0)
    selection = Qt::InputMethodEventAttribute.new(Qt::InputMethodEvent::AttributeType::Selection, 0, 3)
    event = Qt::InputMethodEvent.new("abc", [cursor, selection])
    event.preedit_string.should eq("abc")
    attributes = event.attributes.to_a
    attributes.map(&.type).should eq([Qt::InputMethodEvent::AttributeType::Cursor, Qt::InputMethodEvent::AttributeType::Selection])
    attributes[0].value.to(Int32).should eq(7)
    attributes[1].length.should eq(3)
  end
end

describe Qt::AbstractEventDispatcher do
  it "lists a timer's info" do
    timer = Qt::Timer.new
    timer.start(1000)
    infos = Qt::AbstractEventDispatcher.instance.not_nil!.registered_timers(timer).to_a
    infos.size.should eq(1)
    infos[0].timer_id.should eq(timer.timer_id)
    infos[0].interval.should eq(1000)
    timer.stop

    info = Qt::EventDispatcherTimerInfo.new(1, 50, Qt::TimerType::CoarseTimer)
    info.interval = 60
    info.interval.should eq(60)
    info.timer_type.should eq(Qt::TimerType::CoarseTimer)
  end
end

describe Qt::BasicTimer do
  it "ticks a widget's timer_event" do
    widget = RecordingWidget.new
    loop = Qt::EventLoop.new
    widget.loop = loop
    timer = Qt::BasicTimer.new
    timer.active?.should be_false
    timer.start(1, widget)
    timer.active?.should be_true
    timer.timer_id.should be > 0
    loop.exec.should eq(0)
    timer.stop
    timer.active?.should be_false
    widget.timer_ticks.should eq(2)
  end
end

describe Qt::SignalMapper do
  it "maps a button's click to a string" do
    mapper = Qt::SignalMapper.new
    button = Qt::PushButton.new("one")
    mapper.set_mapping(button, "first")
    mapper.mapping("first").not_nil!.to_unsafe.should eq(button.to_unsafe)
    button.on_clicked { mapper.map(button) }
    received = [] of String
    mapper.on_mapped_string { |text| received << text }
    button.click
    received.should eq(["first"])
    mapper.remove_mappings(button)
    button.click
    received.size.should eq(1)
  end
end

describe Qt::JsonDocument do
  it "parses and serializes objects and arrays" do
    document = Qt::JsonDocument.from_json(%({"name": "qt5", "items": [1, 2.5, {"deep": true}], "none": null}).to_slice)
    document.null?.should be_false
    document.object?.should be_true
    object = document.object
    object.keys.to_a.sort.should eq(["items", "name", "none"])
    object.contains("name").should be_true
    object["name"].to_string.should eq("qt5")
    object.value("none").null?.should be_true
    items = object["items"].to_array
    items.size.should eq(3)
    items.at(0).to_int.should eq(1)
    items.at(1).to_double.should eq(2.5)
    items.at(2).to_object["deep"].to_bool.should be_true
    items.contains(Qt::JsonValue.new(1)).should be_true
    items[1].to_double.should eq(2.5) # A JsonValueRef
    document["name"].to_string.should eq("qt5")

    built = Qt::JsonObject.new
    built.insert("x", Qt::JsonValue.new(1))
    built.insert("s", Qt::JsonValue.new("text"))
    array = Qt::JsonArray.new
    array << Qt::JsonValue.new(true)
    array.append(Qt::JsonValue.new(2.0))
    array[0].assign!(Qt::JsonValue.new(false)) # Writes through the reference
    array.at(0).to_bool.should be_false
    built.insert("a", Qt::JsonValue.new(array))
    built.size.should eq(3)
    built["a"].to_array.last.to_double.should eq(2.0)
    json = String.new(Qt::JsonDocument.new(built).to_json(Qt::JsonDocument::JsonFormat::Compact))
    json.should eq(%({"a":[false,2],"s":"text","x":1}))
    Qt::JsonDocument.from_json(json.to_slice).object.should eq(built)
    Qt::JsonArray.from_string_list(["a", "b"]).size.should eq(2)
    built.remove("x")
    built.contains("x").should be_false
    built.take("s").to_string.should eq("text")
    map = built.to_variant_map # A QVariantMap, Hash-like
    map.keys.should eq(["a"])
    map["a"].to?(String).should be_nil # A list, unknown to Qt::Variant
    Qt::JsonObject.from_variant_map({"n" => Qt.variant(5), "s" => Qt.variant("v")}).size.should eq(2)
    Qt::JsonObject.from_variant_hash({"n" => Qt.variant(5)})["n"].to_int.should eq(5)

    error = Qt::JsonParseError.new
    Qt::JsonDocument.from_json("{bad".to_slice, error).null?.should be_true
    error.error.should_not eq(Qt::JsonParseError::ParseError::NoError)
    error.error_string.should_not be_empty
    error.offset.should be > 0
    Qt::JsonValue.new("s").type.should eq(Qt::JsonValue::Type::String)
    Qt::JsonValue.new(Qt::JsonValue::Type::Null).null?.should be_true
    Qt::JsonValue.from_variant(Qt::Variant.new(7)).to_int.should eq(7)
    Qt::JsonValue.new(7).to_variant.to?(Int64).should eq(7)
  end
end

describe Qt::XmlStreamWriter do
  it "writes XML that the reader reads back" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    writer = Qt::XmlStreamWriter.new(buffer)
    writer.auto_formatting = true
    writer.write_start_document
    writer.write_start_element("root")
    writer.write_attribute("version", "1")
    writer.write_attribute("lang", "en")
    writer.write_text_element("child", "text & more")
    writer.write_empty_element("empty")
    writer.write_comment("note")
    writer.write_end_element
    writer.write_end_document
    writer.has_error?.should be_false
    buffer.close
    xml = String.new(buffer.data)
    xml.should start_with("<?xml")
    xml.should contain(%(<root version="1" lang="en">))
    xml.should contain("text &amp; more")

    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    reader = Qt::XmlStreamReader.new(buffer)
    elements = [] of String
    attributes = [] of {String, String}
    text = ""
    until reader.at_end
      token = reader.read_next
      case token
      when Qt::XmlStreamReader::TokenType::StartElement
        elements << reader.name
        if reader.name == "root"
          attributes = reader.attributes.map { |attribute| {attribute.name, attribute.value} }
          reader.attributes.value("version").should eq("1")
          reader.attributes.has_attribute("lang").should be_true
          reader.attributes.size.should eq(2)
        elsif reader.name == "child"
          text = reader.read_element_text
        end
      when Qt::XmlStreamReader::TokenType::Comment
        reader.text.should eq("note")
      end
    end
    reader.has_error?.should be_false
    elements.should eq(["root", "child", "empty"])
    attributes.should eq([{"version", "1"}, {"lang", "en"}])
    text.should eq("text & more")

    broken = Qt::XmlStreamReader.new("<a><b></a>")
    broken.read_next.should eq(Qt::XmlStreamReader::TokenType::StartDocument)
    until broken.at_end
      broken.read_next
    end
    broken.has_error?.should be_true
    broken.error.should eq(Qt::XmlStreamReader::Error::NotWellFormedError)
    broken.error_string.should_not be_empty
  end
end

describe Qt::DataStream do
  it "writes numbers and strings to a buffer and reads them back" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    stream = Qt::DataStream.new(buffer)
    stream.version = Qt::DataStream::Version::Qt_5_15.to_i
    stream.byte_order = Qt::DataStream::ByteOrder::BigEndian
    stream << 42 << -7_i64 << 2.5 << true << "héllo" << Bytes[1, 2, 3]
    stream << Qt::Point.new(3, 4)
    stream << Qt::Date.new(2024, 2, 29)
    stream.status.should eq(Qt::DataStream::Status::Ok)
    buffer.close
    buffer.data.size.should be > 20

    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    reader = Qt::DataStream.new(buffer)
    reader.version = Qt::DataStream::Version::Qt_5_15.to_i
    reader.read(Int32).should eq(42)
    reader.read(Int64).should eq(-7)
    reader.read(Float64).should eq(2.5)
    reader.read(Bool).should be_true
    reader.read(String).should eq("héllo")
    reader.read(Bytes).should eq(Bytes[1, 2, 3])
    reader.skip_raw_data(8).should eq(8) # The point: `>> Point` takes it by non-const reference
    date = Qt::Date.new
    reader >> date
    date.should eq(Qt::Date.new(2024, 2, 29))
    reader.at_end.should be_true
    reader.read(Int32).should eq(0)
    reader.status.should eq(Qt::DataStream::Status::ReadPastEnd)

    from_bytes = Qt::DataStream.new(Bytes[0, 0, 0, 5])
    from_bytes.read(Int32).should eq(5)
  end
end

describe Qt::BitArray do
  it "holds bits" do
    bits = Qt::BitArray.new(8)
    bits.size.should eq(8)
    bits.count(true).should eq(0)
    bits.set_bit(1, true)
    bits.set_bit(6, true)
    bits.test_bit(1).should be_true
    bits.test_bit(2).should be_false
    bits.at(6).should be_true
    bits.count(true).should eq(2)
    bits.toggle_bit(1).should be_true
    bits.test_bit(1).should be_false
    bits.clear_bit(6)
    bits.count(true).should eq(0)
    bits.fill(true)
    bits.count(true).should eq(8)
    other = Qt::BitArray.new(8, false)
    other.set_bit(0, true)
    (bits & other).count(true).should eq(1)
    (bits ^ other).count(true).should eq(7)
    bits.resize(4)
    bits.size.should eq(4)
    Qt::BitArray.new.empty?.should be_true
  end

  it "reads the process environment" do
    environment = Qt::ProcessEnvironment.system_environment
    environment.empty?.should be_false
    environment.contains("PATH").should be_true
    environment.value("PATH").should contain("/")
    environment.keys.to_a.should contain("PATH")
    environment.to_string_list.to_a.any?(&.starts_with?("PATH=")).should be_true
    own = Qt::ProcessEnvironment.new
    own.insert("QT5CR", "spec")
    own.value("QT5CR").should eq("spec")
    own.value("NOPE", "default").should eq("default")
    own.remove("QT5CR")
    own.contains("QT5CR").should be_false
  end

  it "describes calendars, storage and more" do
    calendar = Qt::Calendar.new
    calendar.gregorian?.should be_true
    calendar.name.should eq("Gregorian")
    calendar.days_in_month(2, 2024).should eq(29)
    calendar.is_leap_year(2023).should be_false
    parts = calendar.parts_from_date(Qt::Date.new(2024, 2, 29))
    parts.valid?.should be_true
    {parts.year, parts.month, parts.day}.should eq({2024, 2, 29})
    calendar.date_from_parts(2024, 3, 1).day_of_year.should eq(61)
    Qt::Calendar.available_calendars.to_a.should contain("Gregorian")
    Qt::Calendar.new(Qt::Calendar::System::Julian).days_in_month(2, 1900).should eq(29)
    calendar.month_name(Qt::Locale.new("en_US"), 2).should eq("February")

    storage = Qt::StorageInfo.root
    storage.valid?.should be_true
    storage.ready?.should be_true
    storage.root?.should be_true
    storage.bytes_total.should be > 0
    storage.root_path.should eq("/")
    Qt::StorageInfo.mounted_volumes.to_a.should_not be_empty
    Qt::StorageInfo.new(Qt::Dir.temp_path).valid?.should be_true

    name = "qt5cr.spec"
    category = Qt::LoggingCategory.new(name.to_unsafe)
    String.new(category.category_name).should eq(name)
    category.debug_enabled?.should be_true
    category.set_enabled(Qt::MsgType::QtDebugMsg, false)
    category.is_enabled(Qt::MsgType::QtDebugMsg).should be_false
    Qt::LoggingCategory.default_category.not_nil!.category_name.null?.should be_false

    mac = Qt::MessageAuthenticationCode.hash("message".to_slice, "key".to_slice, Qt::CryptographicHash::Algorithm::Sha256)
    mac.hexstring.should eq(OpenSSL::HMAC.hexdigest(:sha256, "key", "message"))
    code = Qt::MessageAuthenticationCode.new(Qt::CryptographicHash::Algorithm::Sha256, "key".to_slice)
    code.add_data("mess".to_slice)
    code.add_data("age".to_slice)
    code.result.should eq(mac)

    Qt::Library.new("no such library").load.should be_false
    Qt::Library.is_library("foo.so").should be_true # A library suffix on Linux and macOS
    Qt::Library.is_library("foo.txt").should be_false
    Qt::Resource.new(":/no/such/resource").valid?.should be_false
    selector = Qt::FileSelector.new
    selector.all_selectors.to_a.should_not be_empty
    selector.select("/no/such/file").should eq("/no/such/file")
  end
end

describe Qt::TextCodec do
  it "converts text and sets a text stream's encoding" do
    utf8 = Qt::TextCodec.codec_for_name("UTF-8".to_slice).not_nil!
    String.new(utf8.name).should eq("UTF-8")
    utf8.mib_enum.should eq(106)
    utf8.from_unicode("héllo").should eq("héllo".to_slice)
    utf8.to_unicode("héllo".to_slice).should eq("héllo")
    latin1 = Qt::TextCodec.codec_for_name("ISO-8859-1".to_slice).not_nil!
    latin1.from_unicode("é").should eq(Bytes[0xe9])
    latin1.to_unicode(Bytes[0xe9]).should eq("é")
    latin1.can_encode('é').should be_true
    latin1.can_encode('€').should be_false
    Qt::TextCodec.available_codecs.map { |codec| String.new(codec) }.should contain("UTF-8")
    Qt::TextCodec.codec_for_name("no such codec".to_slice).should be_nil
    Qt::TextCodec.codec_for_mib(106).not_nil!.mib_enum.should eq(106)

    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    stream = Qt::TextStream.new(buffer)
    stream.codec = latin1
    String.new(stream.codec.not_nil!.name).should eq("ISO-8859-1")
    stream << "é"
    stream.flush
    buffer.data.should eq(Bytes[0xe9])
  end
end

describe Qt::Process do
  it "runs a program and reads its output" do
    process = Qt::Process.new
    process.start("/bin/echo", ["hi"])
    process.wait_for_finished.should be_true
    String.new(process.read_all_standard_output).should eq("hi\n")
    process.exit_status.should eq(Qt::Process::ExitStatus::NormalExit)
    process.exit_code.should eq(0)
    process.state.should eq(Qt::Process::ProcessState::NotRunning)
  end

  it "reports a program that fails to start" do
    process = Qt::Process.new
    process.start("/nonexistent/qt5cr", [] of String)
    process.wait_for_started.should be_false
    process.error.should eq(Qt::Process::ProcessError::FailedToStart)
  end
end

describe Qt::Clipboard do
  it "holds text" do
    clipboard = Qt::GuiApplication.clipboard.not_nil!
    clipboard.set_text("copied")
    clipboard.text.should eq("copied")
  end

  it "takes mime data" do
    clipboard = Qt::GuiApplication.clipboard.not_nil!
    data = Qt::MimeData.new
    data.text = "mime"
    clipboard.set_mime_data(data)
    clipboard.mime_data.not_nil!.text.should eq("mime")
  end
end
