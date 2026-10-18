require "../spec_helper"

# A method returning a pointer to a wrapped class returns nil for a null
# pointer with `nilable_results` in `qt.yml`, which bindgen f0929c4 can't yet
# enable for Qt (see there).  Without it, such a result wraps the null pointer.
describe "Null pointers" do
  pending "are returned as nil" do
    list = Qt::ListWidget.new
    list.item(0).should be_nil
    list.add_item("one")
    list.item(0).should_not be_nil
    list.item(0).not_nil!.text.should eq("one")
    list.item(1).should be_nil

    widget = Qt::Widget.new
    widget.parent_widget.should be_nil
    widget.layout.should be_nil
    child = Qt::Widget.new(widget)
    child.parent_widget.should eq(widget)

    item = Qt::StandardItem.new("parent")
    item.child(0).should be_nil
    item.append_row(Qt::StandardItem.new("child"))
    item.child(0).not_nil!.text.should eq("child")
    item.child(1).should be_nil
    item.parent.should be_nil
    item.model.should be_nil
  end
end
