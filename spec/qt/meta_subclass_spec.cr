require "../spec_helper"

# A Crystal subclass declares signals, slots and properties with the `signal`,
# `@[Qt::Slot]` and `qt_property` macros of `Qt::Object`; bindgen builds a
# QMetaObject for the class, so Qt sees them like those of a C++ class.

private class Counter < Qt::Object
  signal value_changed(value : Int32)
  signal renamed(name : String, by : Qt::Object?)

  getter value = 0

  @[Qt::Slot]
  def increment : Nil
    @value += 1
    value_changed(@value)
  end

  @[Qt::Slot]
  def add(a : Int32, b : String) : Int32
    a + b.size
  end

  @[Qt::Slot]
  def set_value(value : Int32) : Nil
    @value = value
    value_changed(value)
  end

  def label : String
    "counter"
  end

  qt_property value : Int32, write: :set_value, notify: :value_changed
  qt_property label : String
end

# A Crystal subclass of a Crystal class with meta-object members: its
# meta-object chains to the parent's.
private class Child < Counter
  signal moved(x : Float64)
end

describe "a Crystal subclass declaring signals, slots and properties" do
  it "describes them through its meta-object" do
    counter = Counter.new
    meta = counter.meta_object.not_nil!
    String.new(meta.class_name).should eq("Counter")
    String.new(meta.super_class.not_nil!.class_name).should eq("QObject")
    meta.method_count.should eq(Qt::Object.static_meta_object.method_count + 5)
    meta.index_of_signal("valueChanged(int)".to_unsafe).should eq(meta.method_offset)
    meta.index_of_signal("renamed(QString,QObject*)".to_unsafe).should eq(meta.method_offset + 1)
    meta.index_of_slot("increment()".to_unsafe).should eq(meta.method_offset + 2)
    meta.index_of_slot("add(int,QString)".to_unsafe).should eq(meta.method_offset + 3)
    meta.index_of_slot("setValue(int)".to_unsafe).should eq(meta.method_offset + 4)
    add = meta.method(meta.method_offset + 3)
    String.new(add.type_name).should eq("int")
    add.parameter_count.should eq(2)
    String.new(add.parameter_names.first).should eq("a")
    counter.inherits("Counter".to_unsafe).should be_true
    counter.inherits("QObject".to_unsafe).should be_true
    Qt::Object.new.inherits("Counter".to_unsafe).should be_false
  end

  it "emits its signals to Crystal blocks" do
    counter = Counter.new
    seen = [] of Int32
    counter.on_value_changed { |value| seen << value }
    counter.increment
    counter.value_changed(7)
    seen.should eq([1, 7])

    names = [] of String
    counter.on_renamed { |name, by| names << "#{name} by #{by.nil? ? "nobody" : "someone"}" }
    counter.renamed("x", nil)
    counter.renamed("y", counter)
    names.should eq(["x by nobody", "y by someone"])
  end

  it "connects a signal by name to a Crystal slot" do
    source = Counter.new
    target = Counter.new
    Qt::Object.connect(source, "2valueChanged(int)".to_unsafe, target, "1setValue(int)".to_unsafe)
    source.increment
    source.increment
    target.value.should eq(2)
  end

  it "invokes a slot by name" do
    counter = Counter.new
    Qt::MetaObject.invoke_method(counter, "increment").should be_true
    counter.value.should eq(1)
    Qt::MetaObject.invoke_method(counter, "nothing").should be_false
  end

  it "reads and writes its properties" do
    counter = Counter.new
    counter.property("value".to_unsafe).to(Int32).should eq(0)
    counter.set_property("value".to_unsafe, Qt.variant(5)).should be_true
    counter.value.should eq(5)
    counter.property("value".to_unsafe).to(Int32).should eq(5)
    counter.property("label".to_unsafe).to(String).should eq("counter")

    meta = counter.meta_object.not_nil!
    value = meta.property(meta.index_of_property("value".to_unsafe))
    value.writable?.should be_true
    value.notify_signal_index.should eq(meta.index_of_signal("valueChanged(int)".to_unsafe))
    String.new(value.type_name).should eq("int")
    meta.property(meta.index_of_property("label".to_unsafe)).writable?.should be_false
  end

  it "chains the meta-object of a Crystal subclass to its Crystal parent's" do
    child = Child.new
    meta = child.meta_object.not_nil!
    String.new(meta.class_name).should eq("Child")
    String.new(meta.super_class.not_nil!.class_name).should eq("Counter")
    meta.index_of_signal("moved(double)".to_unsafe).should eq(meta.method_offset)

    xs = [] of Float64
    child.on_moved { |x| xs << x }
    child.moved(1.5)
    xs.should eq([1.5])

    child.increment
    Qt::MetaObject.invoke_method(child, "increment").should be_true
    child.value.should eq(2)
    child.property("value".to_unsafe).to(Int32).should eq(2)
    child.inherits("Counter".to_unsafe).should be_true
  end
end

# The other types: a wrapped enum and a class passed by value; the
# counterparts of Q_INVOKABLE and Q_CLASSINFO.
private class Shape < Qt::Object
  qt_class_info "Author", "spec"
  qt_class_info "QML.Element", "auto"

  signal flipped(orientation : Qt::Orientation)
  signal painted(color : Qt::Color)

  getter orientation = Qt::Orientation::Horizontal
  getter color = Qt::Color.new(0, 0, 0)
  getter resets = 0

  @[Qt::Slot]
  def set_orientation(orientation : Qt::Orientation) : Nil
    @orientation = orientation
    flipped(orientation)
  end

  @[Qt::Slot]
  def set_color(color : Qt::Color) : Nil
    @color = color
  end

  @[Qt::Invokable]
  def reset : Nil
    @resets += 1
  end

  qt_property orientation : Qt::Orientation, write: :set_orientation, notify: :flipped
  qt_property color : Qt::Color, write: :set_color
end

describe "the types of signals, slots and properties of a Crystal subclass" do
  it "takes a wrapped enum" do
    shape = Shape.new
    meta = shape.meta_object.not_nil!
    meta.index_of_signal("flipped(Qt::Orientation)".to_unsafe).should eq(meta.method_offset)
    String.new(meta.property(meta.index_of_property("orientation".to_unsafe)).type_name).should eq("Qt::Orientation")

    seen = [] of Qt::Orientation
    shape.on_flipped { |orientation| seen << orientation }
    shape.set_orientation(Qt::Orientation::Vertical)
    seen.should eq([Qt::Orientation::Vertical])

    # Through QVariants Qt makes and reads: a slider's orientation property.
    shape.set_orientation(Qt::Orientation::Horizontal)
    vertical = Qt::Slider.new(Qt::Orientation::Vertical)
    shape.set_property("orientation".to_unsafe, vertical.property("orientation".to_unsafe)).should be_true
    shape.orientation.should eq(Qt::Orientation::Vertical)
    horizontal = Qt::Slider.new(Qt::Orientation::Horizontal)
    horizontal.set_property("orientation".to_unsafe, shape.property("orientation".to_unsafe)).should be_true
    horizontal.orientation.should eq(Qt::Orientation::Vertical)

    # Qt converts an int to the enum.
    shape.set_property("orientation".to_unsafe, Qt.variant(Qt::Orientation::Horizontal.value.to_i32)).should be_true
    shape.orientation.should eq(Qt::Orientation::Horizontal)

    # Connected by name to and from Qt's own signals and slots.
    toolbar = Qt::ToolBar.new
    Qt::Object.connect(toolbar, "2orientationChanged(Qt::Orientation)".to_unsafe, shape, "1setOrientation(Qt::Orientation)".to_unsafe)
    toolbar.orientation = Qt::Orientation::Vertical
    shape.orientation.should eq(Qt::Orientation::Vertical)
    Qt::Object.connect(shape, "2flipped(Qt::Orientation)".to_unsafe, horizontal, "1setOrientation(Qt::Orientation)".to_unsafe)
    shape.set_orientation(Qt::Orientation::Horizontal)
    horizontal.orientation.should eq(Qt::Orientation::Horizontal)
  end

  it "takes a class by value, copying it" do
    shape = Shape.new
    names = [] of String
    shape.on_painted { |color| names << color.name }
    shape.painted(Qt::Color.new(255, 0, 0))
    names.should eq(["#ff0000"])

    source = Shape.new
    Qt::Object.connect(source, "2painted(QColor)".to_unsafe, shape, "1setColor(QColor)".to_unsafe)
    source.painted(Qt::Color.new(0, 255, 0))
    shape.color.name.should eq("#00ff00")

    # Through QVariants Qt makes and reads: a color dialog's color property.
    dialog = Qt::ColorDialog.new
    dialog.current_color = Qt::Color.new(0, 0, 255)
    shape.set_property("color".to_unsafe, dialog.property("currentColor".to_unsafe)).should be_true
    shape.color.name.should eq("#0000ff")
    dialog.current_color = Qt::Color.new(255, 255, 255)
    dialog.set_property("currentColor".to_unsafe, shape.property("color".to_unsafe)).should be_true
    dialog.current_color.name.should eq("#0000ff")

    # Connected by name to and from Qt's own signals and slots.
    Qt::Object.connect(dialog, "2currentColorChanged(QColor)".to_unsafe, shape, "1setColor(QColor)".to_unsafe)
    dialog.current_color = Qt::Color.new(1, 2, 3)
    shape.color.name.should eq("#010203")
    effect = Qt::GraphicsColorizeEffect.new
    Qt::Object.connect(shape, "2painted(QColor)".to_unsafe, effect, "1setColor(QColor)".to_unsafe)
    shape.painted(Qt::Color.new(4, 5, 6))
    effect.color.name.should eq("#040506")
  end

  it "has invokable methods which aren't slots" do
    shape = Shape.new
    meta = shape.meta_object.not_nil!
    index = meta.index_of_method("reset()".to_unsafe)
    index.should be >= meta.method_offset
    meta.method(index).method_type.should eq(Qt::MetaMethod::MethodType::Method)
    meta.method(meta.index_of_slot("setColor(QColor)".to_unsafe)).method_type.should eq(Qt::MetaMethod::MethodType::Slot)

    Qt::MetaObject.invoke_method(shape, "reset").should be_true
    shape.resets.should eq(1)

    # A signal connects to it through the QMetaMethods, with more arguments.
    Qt::Object.connect(shape, meta.method(meta.index_of_signal("flipped(Qt::Orientation)".to_unsafe)), shape, meta.method(index))
    shape.set_orientation(Qt::Orientation::Vertical)
    shape.resets.should eq(2)
  end

  it "carries class infos" do
    meta = Shape.new.meta_object.not_nil!
    meta.class_info_count.should eq(2)
    author = meta.class_info(meta.index_of_class_info("Author".to_unsafe))
    String.new(author.name).should eq("Author")
    String.new(author.value).should eq("spec")
    String.new(meta.class_info(meta.index_of_class_info("QML.Element".to_unsafe)).value).should eq("auto")
  end
end
