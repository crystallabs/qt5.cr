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

# Gives *tree* a top-level item with a child, keeping no reference to them.
private def add_items(tree)
  Qt::TreeWidgetItem.new(Qt::TreeWidgetItem.new(tree, ["root"]), ["child"])
  nil
end

describe "items owned by a parent which isn't a QObject" do
  it "aren't collected while their owner holds them" do
    tree = Qt::TreeWidget.new
    add_items(tree)
    churn

    tree.top_level_item_count.should eq(1)
    tree.top_level_item(0).not_nil!.child_count.should eq(1)
  end

  it "are kept alive by the tree, list, item or command given to their constructor" do
    tree = Qt::TreeWidget.new
    root = Qt::TreeWidgetItem.new(tree, ["root"])
    Qt::BindgenHelper.kept_alive?(root).should be_true
    Qt::BindgenHelper.kept_alive?(Qt::TreeWidgetItem.new(root, ["child"])).should be_true
    Qt::BindgenHelper.kept_alive?(Qt::TreeWidgetItem.new(["loose"])).should be_false

    list = Qt::ListWidget.new
    Qt::BindgenHelper.kept_alive?(Qt::ListWidgetItem.new("item", list)).should be_true
    Qt::BindgenHelper.kept_alive?(Qt::ListWidgetItem.new("loose")).should be_false

    command = Qt::UndoCommand.new("parent")
    Qt::BindgenHelper.kept_alive?(Qt::UndoCommand.new("child", command)).should be_true
    Qt::BindgenHelper.kept_alive?(command).should be_false
  end

  it "are released when taken out or deleted" do
    tree = Qt::TreeWidget.new
    root = Qt::TreeWidgetItem.new(tree, ["root"])
    child = Qt::TreeWidgetItem.new(root, ["child"])

    tree.take_top_level_item(0).not_nil!.to_unsafe.should eq(root.to_unsafe)
    Qt::BindgenHelper.kept_alive?(root).should be_false
    Qt::BindgenHelper.kept_alive?(child).should be_true # Its parent item holds it still

    tree.add_top_level_item(root)
    Qt::BindgenHelper.kept_alive?(root).should be_true
    tree.clear # Deletes the items
    Qt::BindgenHelper.kept_alive?(root).should be_false
    Qt::BindgenHelper.kept_alive?(child).should be_false
  end
end

describe "objects kept alive and given a parent" do
  it "stay kept alive when their parent is taken" do
    view = Qt::ListView.new
    model = Qt::StringListModel.new(view)
    view.model = model

    model.parent = nil
    Qt::BindgenHelper.kept_alive?(model).should be_true # The view uses it still
    Qt::BindgenHelper.release(model)
    Qt::BindgenHelper.kept_alive?(model).should be_false
  end

  it "aren't kept when Qt created them" do
    window = Qt::Widget.new
    layout = Qt::VBoxLayout.new(window)
    layout.add_widget(Qt::Label.new("label"))
    label = window.children.first
    Qt::BindgenHelper.kept_alive?(label).should be_true # The object Crystal constructed

    menu = Qt::Menu.new
    action = menu.add_action("entry") # Created by Qt
    Qt::BindgenHelper.keep_alive(action)
    Qt::BindgenHelper.kept_alive?(action).should be_false
  end
end
