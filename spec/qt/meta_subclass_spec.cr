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

# A Crystal enum as a type: an enumerator of the class, like `Q_ENUM`,
# registered with Qt as `Machine::Mode`.
private class Machine < Qt::Object
  enum Mode
    Idle = 0
    Fast = 1
    Slow = 2
  end

  @[Flags]
  enum Options
    Verbose
    Dry
  end

  signal mode_changed(mode : Mode)

  getter mode = Mode::Idle
  getter options = Options::None

  @[Qt::Slot]
  def set_mode(mode : Mode) : Nil
    @mode = mode
    mode_changed(mode)
  end

  @[Qt::Slot]
  def set_options(options : Options) : Nil
    @options = options
  end

  @[Qt::Slot]
  def next_mode : Mode
    Mode.new((@mode.value + 1) % 3)
  end

  qt_property mode : Mode, write: :set_mode, notify: :mode_changed
  qt_property options : Options, write: :set_options
end

describe "a Crystal enum in a Crystal subclass's meta-object" do
  it "is an enumerator of the class, registered with Qt" do
    machine = Machine.new
    meta = machine.meta_object.not_nil!
    meta.enumerator_count.should eq(2)
    mode = meta.enumerator(meta.index_of_enumerator("Mode".to_unsafe))
    String.new(mode.name).should eq("Mode")
    String.new(mode.scope).should eq("Machine")
    mode.key_count.should eq(3)
    mode.key_to_value("Slow".to_unsafe).should eq({2, true})
    String.new(mode.value_to_key(1)).should eq("Fast")
    mode.scoped?.should be_true
    mode.flag?.should be_false
    meta.enumerator(meta.index_of_enumerator("Options".to_unsafe)).flag?.should be_true

    property = meta.property(meta.index_of_property("mode".to_unsafe))
    String.new(property.type_name).should eq("Machine::Mode")
    property.enum_type?.should be_true
    meta.index_of_signal("modeChanged(Machine::Mode)".to_unsafe).should eq(meta.method_offset)
    String.new(meta.method(meta.index_of_slot("nextMode()".to_unsafe)).type_name).should eq("Machine::Mode")
  end

  it "is emitted, received and invoked as the enum" do
    machine = Machine.new
    seen = [] of Machine::Mode
    machine.on_mode_changed { |mode| seen << mode }
    machine.set_mode(Machine::Mode::Fast)
    machine.mode_changed(Machine::Mode::Slow)
    seen.should eq([Machine::Mode::Fast, Machine::Mode::Slow])

    # Connected by name, with the registered type.
    other = Machine.new
    Qt::Object.connect(machine, "2modeChanged(Machine::Mode)".to_unsafe, other, "1setMode(Machine::Mode)".to_unsafe)
    machine.set_mode(Machine::Mode::Idle)
    other.mode.should eq(Machine::Mode::Idle)

    # Queued: the type being registered, Qt copies the argument.
    queued = [] of Machine::Mode
    machine.on_mode_changed(Qt::ConnectionType::QueuedConnection) { |mode| queued << mode }
    machine.set_mode(Machine::Mode::Fast)
    queued.should be_empty
    Qt::CoreApplication.process_events
    queued.should eq([Machine::Mode::Fast])

    Qt::MetaObject.invoke_method(machine, "nextMode").should be_true
  end

  it "goes through QVariants by key, by number and as the enum" do
    machine = Machine.new
    machine.set_property("mode".to_unsafe, Qt.variant("Slow")).should be_true
    machine.mode.should eq(Machine::Mode::Slow)
    machine.set_property("mode".to_unsafe, Qt.variant(1)).should be_true
    machine.mode.should eq(Machine::Mode::Fast)
    machine.set_property("mode".to_unsafe, Qt.variant("Nowhere")).should be_false
    machine.mode.should eq(Machine::Mode::Fast)

    variant = machine.property("mode".to_unsafe)
    variant.to(Machine::Mode).should eq(Machine::Mode::Fast)
    variant.to?(Int32).should be_nil
    variant.to?(String).should be_nil
    machine.set_property("mode".to_unsafe, Qt.variant(Machine::Mode::Slow)).should be_true # Passed as its int
    machine.mode.should eq(Machine::Mode::Slow)
    Qt.variant(Machine::Mode::Slow).to(Machine::Mode).should eq(Machine::Mode::Slow)
    Qt.variant(Machine::Mode::Slow).to(Int32).should eq(2)

    machine.set_property("options".to_unsafe, Qt.variant("Verbose|Dry")).should be_true
    machine.options.should eq(Machine::Options::Verbose | Machine::Options::Dry)
    machine.property("options".to_unsafe).to(Machine::Options).should eq(Machine::Options::All)

    # A wrapped enum Qt hands out unpacks as the enum too.
    slider = Qt::Slider.new(Qt::Orientation::Vertical)
    slider.property("orientation".to_unsafe).to(Qt::Orientation).should eq(Qt::Orientation::Vertical)
    slider.property("orientation".to_unsafe).to?(Machine::Mode).should eq(Machine::Mode::Slow) # Its value is 2: Qt's enums aren't told apart
    Qt.variant(1).to(Machine::Mode).should eq(Machine::Mode::Fast)                             # An integer unpacks as an enum
    Qt.variant("1").to?(Machine::Mode).should be_nil
  end
end

# The converted value types: `Qt::Variant` crosses as a `QVariant`, `Char` as a
# `QChar`, through the conversions bindgen generates for the type rules.
private class Store < Qt::Object
  signal stored(value : Qt::Variant)
  signal data_changed(key : String, value : Qt::Variant)
  signal marked(mark : Char)

  getter data = Qt::Variant.new(nil)
  getter mark = 'a'

  @[Qt::Slot]
  def set_data(value : Qt::Variant) : Nil
    @data = value
    stored(value)
    data_changed("data", value)
  end

  @[Qt::Slot]
  def set_mark(mark : Char) : Nil
    @mark = mark
  end

  @[Qt::Slot]
  def describe(value : Qt::Variant) : Qt::Variant
    Qt.variant("#{value.to?(Int32)}!")
  end

  qt_property data : Qt::Variant, write: :set_data, notify: :data_changed
  qt_property mark : Char, write: :set_mark
end

describe "a converted value type in a Crystal subclass's meta-object" do
  it "takes a Qt::Variant as a QVariant" do
    store = Store.new
    meta = store.meta_object.not_nil!
    String.new(meta.property(meta.index_of_property("data".to_unsafe)).type_name).should eq("QVariant")
    meta.index_of_signal("dataChanged(QString,QVariant)".to_unsafe).should eq(meta.method_offset + 1)
    String.new(meta.method(meta.index_of_slot("describe(QVariant)".to_unsafe)).type_name).should eq("QVariant")

    seen = [] of {String, Qt::Variant}
    store.on_data_changed { |key, value| seen << {key, value} }
    store.set_data(Qt.variant(42))
    seen.size.should eq(1)
    seen[0][0].should eq("data")
    seen[0][1].to(Int32).should eq(42)

    # Through QVariants Qt makes and reads: as they are.
    store.set_property("data".to_unsafe, Qt.variant("text")).should be_true
    store.data.to(String).should eq("text")
    store.property("data".to_unsafe).to(String).should eq("text")
    store.set_property("data".to_unsafe, Qt.variant([1, 2])).should be_true # A Crystal value, kept
    store.data.to(Array(Int32)).should eq([1, 2])
    store.property("data".to_unsafe).to(Array(Int32)).should eq([1, 2])
    store.set_property("data".to_unsafe, Qt.variant(nil)).should be_true
    store.data.is_nil?.should be_true

    # Connected by name, and queued.
    other = Store.new
    Qt::Object.connect(store, "2stored(QVariant)".to_unsafe, other, "1setData(QVariant)".to_unsafe)
    store.set_data(Qt.variant(1.5))
    other.data.to(Float64).should eq(1.5)
    queued = [] of Qt::Variant
    store.on_stored(Qt::ConnectionType::QueuedConnection) { |value| queued << value }
    store.set_data(Qt.variant("later"))
    queued.should be_empty
    Qt::CoreApplication.process_events
    queued.map(&.to(String)).should eq(["later"])
  end

  it "takes a Char as a QChar" do
    store = Store.new
    meta = store.meta_object.not_nil!
    String.new(meta.property(meta.index_of_property("mark".to_unsafe)).type_name).should eq("QChar")
    meta.index_of_signal("marked(QChar)".to_unsafe).should eq(meta.method_offset + 2)

    marks = [] of Char
    store.on_marked { |mark| marks << mark }
    store.marked('x')
    store.marked('€')
    marks.should eq(['x', '€'])

    store.set_property("mark".to_unsafe, Qt.variant('z')).should be_true
    store.mark.should eq('z')
    store.property("mark".to_unsafe).to(Char).should eq('z')
  end
end

# Containers: an `Array(T)` or `Enumerable(T)` is the first sequential
# container of `T` the binding instantiates (`QList<int>`), a `Set(T)` the
# `QSet<T>`, a `Hash(K, V)` the first associative container (`QMap<QString,
# QVariant>`), registered with QMetaType by name.
private class Bag < Qt::Object
  signal items_changed(items : Array(Int32))
  signal named(names : Enumerable(String))
  signal tagged(tags : Set(Int32))
  signal settings_changed(settings : Hash(String, Qt::Variant))

  getter items = [] of Int32
  getter settings = {} of String => Qt::Variant
  getter counted = 0

  @[Qt::Slot]
  def set_items(items : Array(Int32)) : Nil
    @items = items
    items_changed(items)
  end

  @[Qt::Slot]
  def set_settings(settings : Hash(String, Qt::Variant)) : Nil
    @settings = settings
    settings_changed(settings)
  end

  @[Qt::Slot]
  def count_names(names : Enumerable(String)) : Int32
    @counted = names.size
  end

  qt_property items : Array(Int32), write: :set_items, notify: :items_changed
  qt_property settings : Hash(String, Qt::Variant), write: :set_settings
end

describe "a container in a Crystal subclass's meta-object" do
  it "is the instantiated container, registered with Qt" do
    bag = Bag.new
    meta = bag.meta_object.not_nil!
    list = String.new(meta.property(meta.index_of_property("items".to_unsafe)).type_name)
    list.should match(/^Q(List|Vector)<int>$/)
    String.new(meta.property(meta.index_of_property("settings".to_unsafe)).type_name).should eq("QVariantMap") # Qt's name of the builtin
    meta.index_of_signal("itemsChanged(#{list})".to_unsafe).should eq(meta.method_offset)
    meta.index_of_signal("named(QList<QString>)".to_unsafe).should eq(meta.method_offset + 1)
    meta.index_of_signal("tagged(QSet<int>)".to_unsafe).should eq(meta.method_offset + 2)
    meta.index_of_slot("countNames(QList<QString>)".to_unsafe).should eq(meta.method_offset + 6)
  end

  it "is emitted and received as the declared generic" do
    bag = Bag.new
    items = [] of Int32
    bag.on_items_changed { |list| items = list }
    bag.set_items([1, 2, 3])
    items.should eq([1, 2, 3])

    names = [] of String
    bag.on_named { |list| names = list.to_a }
    bag.named(["a", "b"])
    names.should eq(["a", "b"])
    bag.named(Qt::StringList.new.concat(["c"])) # The container itself is an Enumerable(String)
    names.should eq(["c"])

    tags = Set(Int32).new
    bag.on_tagged { |set| tags = set }
    bag.tagged(Set{3, 4})
    tags.should eq(Set{3, 4})

    settings = {} of String => Qt::Variant
    bag.on_settings_changed { |hash| settings = hash }
    bag.set_settings({"a" => Qt.variant(1), "b" => Qt.variant("two")})
    settings.keys.sort.should eq(["a", "b"])
    settings["b"].to(String).should eq("two")

    # Connected by name, between Crystal objects, and queued: the types are
    # registered, so Qt copies them.
    other = Bag.new
    list = String.new(bag.meta_object.not_nil!.property(bag.meta_object.not_nil!.index_of_property("items".to_unsafe)).type_name)
    Qt::Object.connect(bag, "2itemsChanged(#{list})".to_unsafe, other, "1setItems(#{list})".to_unsafe)
    Qt::Object.connect(bag, "2named(QList<QString>)".to_unsafe, other, "1countNames(QList<QString>)".to_unsafe)
    bag.set_items([7])
    other.items.should eq([7])
    bag.named(["x", "y", "z"])
    other.counted.should eq(3)
    queued = [] of Array(Int32)
    bag.on_items_changed(Qt::ConnectionType::QueuedConnection) { |list| queued << list }
    bag.set_items([8, 9])
    queued.should be_empty
    Qt::CoreApplication.process_events
    queued.should eq([[8, 9]])
  end

  it "goes through QVariants as the container type" do
    bag = Bag.new
    bag.set_items([1, 2])
    bag.set_settings({"k" => Qt.variant(5)})
    other = Bag.new
    other.set_property("items".to_unsafe, bag.property("items".to_unsafe)).should be_true
    other.items.should eq([1, 2])
    other.set_property("settings".to_unsafe, bag.property("settings".to_unsafe)).should be_true
    other.settings["k"].to(Int32).should eq(5)
  end
end
