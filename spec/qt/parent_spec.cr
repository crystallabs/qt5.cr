require "../spec_helper"

# Qt makes a parent own its children, and refers to them from memory the GC
# doesn't scan.  The `Qt` processor of bindgen keeps an object given a parent
# alive, so the GC doesn't destroy it, and take it out of its parent.

# Gives *window* a named label, keeping no reference to it.
private def add_label(window)
  Qt::Label.new("label", window).object_name = "kept"
  nil
end

# Gives *parent* a child item, keeping no reference to it.
private def add_item(parent)
  Qt::GraphicsRectItem.new(parent)
  nil
end

private def churn
  10.times do
    GC.collect
    Array(Int32).new(100_000) { |i| i } # Churn the heap
  end
  GC.collect
end

describe "objects with a parent" do
  it "aren't collected while their parent owns them" do
    window = Qt::Widget.new
    add_label(window)
    churn

    window.children.size.should eq(1)
    window.children.first.object_name.should eq("kept")
  end

  it "are kept alive, and those without parent aren't" do
    window = Qt::Widget.new
    Qt::BindgenHelper.kept_alive?(Qt::Label.new("label", window)).should be_true
    Qt::BindgenHelper.kept_alive?(Qt::Object.new(window)).should be_true
    Qt::BindgenHelper.kept_alive?(Qt::Label.new("label")).should be_false
    Qt::BindgenHelper.kept_alive?(window).should be_false
  end

  it "are kept alive by #parent=, and released by #parent = nil" do
    window = Qt::Widget.new
    label = Qt::Label.new("label")

    label.parent = window
    Qt::BindgenHelper.kept_alive?(label).should be_true
    window.children.size.should eq(1)

    label.parent = nil
    Qt::BindgenHelper.kept_alive?(label).should be_false
    window.children.size.should eq(0)
  end

  it "are released when their parent deletes them" do
    window = Qt::Widget.new
    label = Qt::Label.new("label", window)
    Qt::BindgenHelper.kept_alive?(label).should be_true

    window.delete_later
    Qt::CoreApplication.send_posted_events(nil, Qt::Event::Type::DeferredDelete.value.to_i)
    Qt::BindgenHelper.kept_alive?(label).should be_false
  end
end

describe "graphics items with a parent item" do
  it "aren't collected while their parent item owns them" do
    parent = Qt::GraphicsRectItem.new
    add_item(parent)
    churn

    parent.child_items.size.should eq(1)
  end

  it "are kept alive by #parent_item=, and released by #parent_item = nil" do
    parent = Qt::GraphicsRectItem.new
    item = Qt::GraphicsRectItem.new(parent)
    Qt::BindgenHelper.kept_alive?(item).should be_true

    item.parent_item = nil
    Qt::BindgenHelper.kept_alive?(item).should be_false
    parent.child_items.size.should eq(0)

    item.parent_item = parent
    Qt::BindgenHelper.kept_alive?(item).should be_true
  end

  it "are released when their parent item is deleted" do
    scene = Qt::GraphicsScene.new
    parent = Qt::GraphicsRectItem.new
    item = Qt::GraphicsRectItem.new(parent)
    scene.add_item(parent)
    Qt::BindgenHelper.kept_alive?(item).should be_true

    scene.clear # Deletes the parent item, which deletes its child
    Qt::BindgenHelper.kept_alive?(item).should be_false
  end
end
