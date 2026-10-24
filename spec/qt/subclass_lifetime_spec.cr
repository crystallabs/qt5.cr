require "weak_ref"
require "../spec_helper"

# Qt calls the overrides of a Crystal subclass through the Crystal object, which
# the C++ object doesn't refer to.  So an instance of a Crystal subclass is
# collected like any other object once nothing holds it, and lives on with its
# overrides while its parent owns it, or a signal of it is connected.

private class CountingObject < Qt::Object
  class_property events = 0

  def event(event : Qt::Event) : Bool
    CountingObject.events += 1
    super
  end
end

private def send_user_event(object)
  Qt::CoreApplication.send_event(object, Qt::Event.new(Qt::Event::Type::User))
end

# Creates a `CountingObject`, sends it an event and leaves it behind.
private def leave_object : WeakRef(CountingObject)
  object = CountingObject.new
  send_user_event(object)
  WeakRef.new(object)
end

# Gives *parent* a `CountingObject` child, keeping no reference to it.
private def leave_child(parent)
  CountingObject.new(parent)
  nil
end

# Creates a `CountingObject` with a connected signal, and leaves it behind.
private def leave_connected : WeakRef(CountingObject)
  object = CountingObject.new
  object.on_object_name_changed { }
  WeakRef.new(object)
end

# Overwrites the stack below its caller, as a pointer to a dead object left in
# a slot of a frame keeps the object alive.
@[NoInline]
private def scrub_stack
  buffer = uninitialized UInt8[65536]
  buffer.to_slice.fill(0)
end

private def churn
  10.times do
    GC.collect
    Array(Int32).new(100_000) { |i| i } # Churn the heap
  end
  GC.collect
end

describe "an instance of a Crystal subclass overriding a virtual method" do
  it "is collected once Crystal drops it" do
    events = CountingObject.events
    weak = leave_object
    CountingObject.events.should eq(events + 1)

    scrub_stack
    churn
    weak.value.should be_nil
  end

  it "lives on with its parent, and its overrides with it" do
    events = CountingObject.events
    parent = Qt::Object.new
    leave_child(parent)
    scrub_stack
    churn

    child = parent.children.first
    child.should be_a(CountingObject)
    send_user_event(child).should be_true
    CountingObject.events.should eq(events + 1)
  end

  it "lives on while a signal of it is connected, and its overrides with it" do
    events = CountingObject.events
    weak = leave_connected
    scrub_stack
    churn

    object = weak.value.should_not be_nil
    Qt::BindgenHelper.kept_alive?(object).should be_true
    send_user_event(object).should be_true
    CountingObject.events.should eq(events + 1)
  end
end
