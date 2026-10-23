require "../spec_helper"

# Qt owns the objects added to these, but refers to them from memory the GC
# doesn't scan.  Without `keep_alive:` in `config/keep_alive.yml`, the GC
# destroys them, and crashes in their finalizers.
private def fill(layout, list, tabs)
  5.times do |i|
    layout.add_widget Qt::Label.new("label #{i}")
    list.add_item Qt::ListWidgetItem.new("item #{i}")
    tabs.add_tab Qt::Widget.new, "tab #{i}"
  end
end

# Qt keeps a pointer to these without taking ownership, from memory the GC
# doesn't scan either.
private def assign(view, button)
  view.model = Qt::StandardItemModel.new(3, 2)
  button.menu = Qt::Menu.new("menu")
end

# Builds a tree of four items, two of them top-level.  Returns the tree and
# its items: Qt owns the items, but doesn't keep them alive for the GC, which
# would take them out of the tree.
private def build_tree
  tree = Qt::TreeWidget.new
  root = Qt::TreeWidgetItem.new(tree, ["root"])
  child = Qt::TreeWidgetItem.new(root, ["child"])
  other = Qt::TreeWidgetItem.new(tree, ["other"])
  grandchild = Qt::TreeWidgetItem.new(other, ["grandchild"])
  {tree, [root, child, other, grandchild]}
end

# Iterates *tree* with iterators over the tree, over an item, and with flags,
# keeping none of them.  Returns the number of items seen.  The iterators
# unregister from the tree's model when destroyed, from memory the GC doesn't
# scan.  Without `depends_on:` in `config/keep_alive.yml`, the GC may destroy
# the tree first, and crashes in the iterators' finalizers.
private def iterate(tree)
  all = Qt::TreeWidgetItemIterator.new(tree).size
  Qt::TreeWidgetItemIterator.new(tree.top_level_item(1).not_nil!).size.should eq(2)
  Qt::TreeWidgetItemIterator.new(tree, Qt::TreeWidgetItemIterator::IteratorFlags::NoChildren).size.should eq(2)
  copy = Qt::TreeWidgetItemIterator.new(Qt::TreeWidgetItemIterator.new(tree))
  copy.succ!.value.not_nil!.text(0).should eq("child")
  copy.pred!.value.not_nil!.text(0).should eq("root")
  all
end

# Builds a window with a label in its layout, and returns both.  The layout
# keeps the label alive, and Qt made the window its parent: deleting the window
# deletes the label, which releases it.
private def label_of_a_window
  window = Qt::Widget.new
  layout = Qt::VBoxLayout.new(window)
  label = Qt::Label.new("label")
  layout.add_widget(label)
  {window, label}
end

private def churn
  10.times do
    GC.collect
    Array(Int32).new(100_000) { |i| i } # Churn the heap
  end
  GC.collect
end

describe "objects used by Qt" do
  it "aren't collected while Qt owns them" do
    layout = Qt::VBoxLayout.new
    list = Qt::ListWidget.new
    tabs = Qt::TabWidget.new
    fill(layout, list, tabs)
    churn

    layout.count.should eq(5)
    list.count.should eq(5)
    5.times { |i| list.item(i).not_nil!.text.should eq("item #{i}") }
    tabs.count.should eq(5)
  end

  it "aren't collected while Qt keeps a pointer to them" do
    view = Qt::TableView.new
    button = Qt::PushButton.new
    assign(view, button)
    churn

    view.model.not_nil!.row_count.should eq(3)
    button.menu.not_nil!.title.should eq("menu")
  end
end

describe "objects used by Qt through an override" do
  it "aren't collected either" do
    # QTreeView::setModel and QSortFilterProxyModel::setSourceModel re-declare
    # the setters of their base classes, whose keep_alive rules cover them.
    tree = Qt::TreeView.new
    proxy = Qt::SortFilterProxyModel.new
    tree.model = Qt::StandardItemModel.new(3, 1)
    proxy.source_model = Qt::StandardItemModel.new(4, 1)
    churn

    tree.model.not_nil!.row_count.should eq(3)
    proxy.row_count.should eq(4)
  end
end

describe "objects destroyed before others" do
  it "destroys the iterators of a tree before the tree" do
    tree, items = build_tree
    iterate(tree).should eq(4)
    churn
    tree.top_level_item_count.should eq(2)
    items.size.should eq(4)

    3.times { iterate(build_tree[0]).should eq(4) }
    churn
    build_tree[0].top_level_item_count.should eq(2)
  end

  it "keeps the application alive for Qt" do
    churn
    # Reads the arguments Qt keeps a pointer to in the application wrapper
    Qt::CommandLineParser.new.help_text.should contain("Usage")
  end
end

describe "objects deleted by Qt" do
  it "are released when their parent deletes them" do
    window, label = label_of_a_window
    Qt::BindgenHelper.kept_alive?(label).should be_true

    window.delete_later
    Qt::CoreApplication.send_posted_events(nil, Qt::Event::Type::DeferredDelete.value.to_i)
    Qt::BindgenHelper.kept_alive?(label).should be_false
  end
end
