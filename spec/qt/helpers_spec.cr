require "../spec_helper"

# The hand-written helpers of src/qt5/.

# Returns the row, column, row span and column span of *widget* in *grid*.
private def grid_position(grid, widget)
  row = column = row_span = column_span = 0
  grid.get_item_position(grid.index_of(widget), pointerof(row), pointerof(column), pointerof(row_span), pointerof(column_span))
  {row, column, row_span, column_span}
end

describe "Qt::GridLayout#[]=" do
  it "takes the row before the column" do
    grid = Qt::GridLayout.new
    label = Qt::Label.new
    grid[2, 1] = label
    grid_position(grid, label).should eq({2, 1, 1, 1})
  end

  it "spans the cells of a range" do
    grid = Qt::GridLayout.new
    label = Qt::Label.new
    grid[0..1, 1...4] = label
    grid_position(grid, label).should eq({0, 1, 2, 3})
  end

  it "takes a range of one cell" do
    grid = Qt::GridLayout.new
    label = Qt::Label.new
    grid[1..1, 0] = label
    grid_position(grid, label).should eq({1, 0, 1, 1})
  end

  it "counts a negative index from the last row or column" do
    grid = Qt::GridLayout.new
    grid[2, 3] = Qt::Label.new
    label = Qt::Label.new
    grid[-1, -2] = label
    grid_position(grid, label).should eq({2, 2, 1, 1})
  end

  it "raises for an empty range" do
    grid = Qt::GridLayout.new
    expect_raises(IndexError) { grid[1...1, 0] = Qt::Label.new }
  end

  it "adds a layout and a layout item" do
    grid = Qt::GridLayout.new
    inner = Qt::HBoxLayout.new
    grid[0, 1] = inner
    grid.item_at_position(0, 1).not_nil!.layout.not_nil!.to_unsafe.should eq(inner.to_unsafe)

    spacer = Qt::SpacerItem.horizontal
    grid[1, 0] = spacer
    grid.item_at_position(1, 0).not_nil!.spacer_item.not_nil!.to_unsafe.should eq(spacer.to_unsafe)
  end
end

describe "Qt::SpacerItem" do
  it "expands horizontally" do
    policy = Qt::SpacerItem.horizontal.size_policy
    policy.horizontal_policy.should eq(Qt::SizePolicy::Policy::Expanding)
    policy.vertical_policy.should eq(Qt::SizePolicy::Policy::Minimum)
  end

  it "expands vertically" do
    policy = Qt::SpacerItem.vertical.size_policy
    policy.horizontal_policy.should eq(Qt::SizePolicy::Policy::Minimum)
    policy.vertical_policy.should eq(Qt::SizePolicy::Policy::Expanding)
  end

  it "takes another policy" do
    spacer = Qt::SpacerItem.horizontal(Qt::SizePolicy::Policy::Fixed)
    spacer.size_policy.horizontal_policy.should eq(Qt::SizePolicy::Policy::Fixed)
  end
end

describe "Qt::TabWidget#[]=" do
  it "builds a tab widget from a hash-like literal" do
    first = Qt::Label.new
    second = Qt::Label.new
    tabs = Qt::TabWidget{"a" => first, "b" => second}
    tabs.count.should eq(2)
    tabs.tab_text(0).should eq("a")
    tabs.tab_text(1).should eq("b")
    tabs.index_of(second).should eq(1)
  end
end

describe "Qt::Layout#<<" do
  it "adds a widget" do
    layout = Qt::VBoxLayout.new
    label = Qt::Label.new
    (layout << label).should be(layout)
    layout.index_of(label).should eq(0)
  end

  it "adds a layout" do
    layout = Qt::VBoxLayout.new
    inner = Qt::HBoxLayout.new
    layout << inner
    layout.item_at(0).not_nil!.layout.not_nil!.to_unsafe.should eq(inner.to_unsafe)
  end

  it "adds a layout item" do
    layout = Qt::VBoxLayout.new
    spacer = Qt::SpacerItem.vertical
    layout << spacer
    layout.item_at(0).not_nil!.spacer_item.not_nil!.to_unsafe.should eq(spacer.to_unsafe)
  end

  it "chains" do
    layout = Qt::VBoxLayout.new
    layout << Qt::Label.new << Qt::Label.new
    layout.count.should eq(2)
  end
end

describe "Qt::Painter#restore_after" do
  it "restores the state the block changed" do
    image = Qt::Image.new(4, 4, Qt::Image::Format::Argb32)
    Qt::Painter.draw(image) do |painter|
      painter.opacity = 0.25
      painter.restore_after { painter.opacity = 0.75 }
      painter.opacity.should eq(0.25)
    end
  end

  it "restores the state when the block raises" do
    image = Qt::Image.new(4, 4, Qt::Image::Format::Argb32)
    Qt::Painter.draw(image) do |painter|
      expect_raises(Exception, "oops") do
        painter.restore_after do
          painter.opacity = 0.5
          raise "oops"
        end
      end
      painter.opacity.should eq(1.0)
    end
  end
end
