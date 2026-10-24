require "../spec_helper"

# A pointer result or callback argument is wrapped in the class of the
# object's dynamic type, the most derived class the binding knows.

private class EventRecorder < Qt::Widget
  getter classes = [] of Qt::Event.class

  def event(event : Qt::Event) : Bool
    @classes << event.class
    super
  end
end

private class MyLabel < Qt::Label
end

describe "Type discovery" do
  it "wraps children in their own classes" do
    parent = Qt::Widget.new
    Qt::Label.new("l", parent)
    Qt::PushButton.new("b", parent)
    children = parent.children
    children.map(&.class).should eq([Qt::Label, Qt::PushButton])
    children.each { |child| child.should be_a(Qt::Object) }
  end

  it "wraps a result declared abstract in the concrete class" do
    group = Qt::ButtonGroup.new
    button = Qt::PushButton.new("ok")
    group.add_button(button, 3)
    group.buttons.first.should be_a(Qt::PushButton)
    group.buttons.first.should_not be_a(Qt::AbstractButtonImpl)
    found = group.button(3).not_nil!
    found.class.should eq(Qt::PushButton)
    found.to_unsafe.should eq(button.to_unsafe)

    model = Qt::StandardItemModel.new
    view = Qt::ListView.new
    view.model = model
    view.model.not_nil!.class.should eq(Qt::StandardItemModel)
  end

  it "wraps a signal block argument" do
    group = Qt::ButtonGroup.new
    button = Qt::PushButton.new("ok")
    group.add_button(button)
    got = nil.as(Qt::AbstractButton?)
    group.on_button_clicked { |b| got = b }
    button.click
    got.should be_a(Qt::PushButton)
    got.not_nil!.to_unsafe.should eq(button.to_unsafe)
  end

  it "wraps an override's argument" do
    widget = EventRecorder.new
    event = Qt::KeyEvent.new(Qt::Event::Type::KeyPress, Qt::Key::A.value.to_i32, Qt::KeyboardModifiers::NoModifier, "a")
    Qt::CoreApplication.send_event(widget, event)
    widget.classes.should contain(Qt::KeyEvent)
  end

  it "wraps an object of a Crystal subclass in its wrapper class" do
    parent = Qt::Widget.new
    mine = MyLabel.new("mine", parent)
    child = parent.children.first
    child.class.should eq(Qt::Label)
    child.to_unsafe.should eq(mine.to_unsafe)
  end

  it "wraps the application in Qt::Application" do
    Qt::CoreApplication.instance.not_nil!.class.should eq(Qt::Application)
  end
end
