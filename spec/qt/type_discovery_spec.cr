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

private class NotedLabel < Qt::Label
  property note = ""
end

private class NotedButton < Qt::PushButton
  property note = ""
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

  it "returns the Crystal object which constructed an object" do
    parent = Qt::Widget.new
    label = Qt::Label.new("l", parent)
    button = Qt::PushButton.new("b", parent)
    children = parent.children
    children[0].should be(label)
    children[1].should be(button)
  end

  it "returns an instance of a Crystal subclass with its instance variables" do
    parent = Qt::Widget.new
    mine = MyLabel.new("mine", parent)
    child = parent.children.first
    child.should be(mine)
    child.class.should eq(MyLabel)
    child.to_unsafe.should eq(mine.to_unsafe)

    noted = NotedLabel.new("noted", parent)
    noted.note = "kept"
    parent.children.last.as(NotedLabel).note.should eq("kept")
    parent.children.last.should be(noted)
  end

  it "keeps the Crystal object through a signal argument and to?" do
    group = Qt::ButtonGroup.new
    button = NotedButton.new("ok")
    button.note = "signal"
    group.add_button(button)
    got = nil.as(Qt::AbstractButton?)
    group.on_button_clicked { |b| got = b }
    button.click
    got.should be(button)
    got.as(NotedButton).note.should eq("signal")

    label = Qt::Label.new("l")
    widget = label.to?(Qt::Widget).not_nil!
    widget.should be(label)
    widget.to?(Qt::Label).should be(label)
    pb = Qt::PushButton.new("b")
    pb.to?(Qt::Widget).not_nil!.to?(Qt::PushButton).should be(pb)
  end

  it "wraps an object Qt created anew on each retrieval" do
    spin = Qt::SpinBox.new
    edit = spin.children.find { |c| c.is_a?(Qt::LineEdit) }.not_nil!
    spin.children.find { |c| c.is_a?(Qt::LineEdit) }.not_nil!.should_not be(edit)
    edit.to_unsafe.should eq(spin.children.find { |c| c.is_a?(Qt::LineEdit) }.not_nil!.to_unsafe)
  end

  it "wraps the application in Qt::Application" do
    Qt::CoreApplication.instance.not_nil!.class.should eq(Qt::Application)
  end
end
