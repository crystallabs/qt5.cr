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

describe "objects owned by Qt" do
  it "aren't collected by the GC" do
    layout = Qt::VBoxLayout.new
    list = Qt::ListWidget.new
    tabs = Qt::TabWidget.new
    fill(layout, list, tabs)

    10.times do
      GC.collect
      Array(Int32).new(100_000) { |i| i } # Churn the heap
    end
    GC.collect

    layout.count.should eq(5)
    list.count.should eq(5)
    5.times { |i| list.item(i).text.should eq("item #{i}") }
    tabs.count.should eq(5)
  end
end
