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
