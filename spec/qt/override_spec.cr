require "../spec_helper"

# `super` in an override calls the C++ implementation of the class the Crystal
# class derives from, like `superclass.method(args)`.
private class CountingEdit < Qt::LineEdit
  getter presses = 0

  def key_press_event(event : Qt::KeyEvent) : Void
    @presses += 1
    super
  end
end

private class HintWidget < Qt::Widget
  def size_hint : Qt::Size
    hint = super
    Qt::Size.new(hint.width + 1, hint.height + 2)
  end
end

# Overrides nothing: its wrappers call the C++ implementations.
private class PlainWidget < Qt::Widget
end

private class RaisingObject < Qt::Object
  def event(event : Qt::Event) : Bool
    raise "in an override"
  end
end

private def with_exception_handler(&)
  caught = [] of Exception
  default = Qt::BindgenHelper.on_exception
  Qt::BindgenHelper.on_exception = ->(exception : Exception) { caught << exception; nil }
  begin
    yield
  ensure
    Qt::BindgenHelper.on_exception = default
  end
  caught.map(&.message)
end

describe "overrides" do
  it "call the C++ implementation with super" do
    edit = CountingEdit.new
    edit.show
    event = Qt::KeyEvent.new(Qt::Event::Type::KeyPress, Qt::Key::A.value.to_i32, Qt::KeyboardModifiers::NoModifier, "a")
    Qt::Application.send_event(edit, event)
    edit.presses.should eq(1)
    edit.text.should eq("a") # QLineEdit::keyPressEvent inserted it
  end

  it "return the result of super" do
    plain = PlainWidget.new.size_hint
    hint = HintWidget.new.size_hint
    hint.width.should eq(plain.width + 1)
    hint.height.should eq(plain.height + 2)
  end

  it "rescue an exception, returning a zero to C++" do
    object = RaisingObject.new
    messages = with_exception_handler do
      Qt::Application.send_event(object, Qt::Event.new(Qt::Event::Type::User)).should be_false
    end
    messages.should eq(["in an override"])
  end
end

describe "signal blocks" do
  it "rescue an exception" do
    spin_box = Qt::SpinBox.new
    spin_box.on_value_changed { |value| raise "in a slot: #{value}" }
    messages = with_exception_handler { spin_box.value = 3 }
    messages.should eq(["in a slot: 3"])
  end
end
