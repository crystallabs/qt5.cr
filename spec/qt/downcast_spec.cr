require "../spec_helper"

# `#to?` downcasts with C++'s dynamic_cast, so the binding is built with RTTI
# (see ext/Makefile).
describe "Downcasts" do
  it "cast to the dynamic type" do
    button = Qt::PushButton.new("ok")
    widget = button.as(Qt::Widget)
    widget.to?(Qt::Label).should be_nil
    cast = widget.to?(Qt::PushButton)
    cast.should_not be_nil
    cast.not_nil!.text.should eq("ok")
    cast.not_nil!.to_unsafe.should eq(button.to_unsafe)
    widget.to?(Qt::Widget).should eq(widget)

    parent = Qt::Widget.new
    Qt::Label.new("child", parent)
    parent.children.map(&.to?(Qt::Label)).compact.map(&.text).should eq(["child"])
  end

  it "cast to an abstract class" do
    parent = Qt::Widget.new
    Qt::PushButton.new("ok", parent)
    # The child is wrapped in its dynamic type, which is-a Qt::AbstractButton.
    cast = parent.children.first.to?(Qt::AbstractButton)
    cast.should be_a(Qt::PushButton)
    cast.not_nil!.text.should eq("ok")
    parent.to?(Qt::AbstractButton).should be_nil
    # A wrapper of the class already (or of a subclass) is returned as is.
    button = Qt::PushButton.new("ok")
    button.as(Qt::Widget).to?(Qt::AbstractButton).should be(button)
  end
end
