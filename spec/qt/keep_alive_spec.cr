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
