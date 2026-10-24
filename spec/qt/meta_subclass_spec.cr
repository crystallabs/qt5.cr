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
