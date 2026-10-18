require "../spec_helper"

# `QStringList` is a `QList<QString>`, which the binding passes and returns as
# `Enumerable(String)`.
describe "QStringList" do
  it "is passed to Qt" do
    combo = Qt::ComboBox.new
    combo.add_items(["one", "two", "three"])
    combo.count.should eq(3)
    combo.item_text(2).should eq("three")

    list = Qt::ListWidget.new
    list.add_items({"a", "b"})
    list.count.should eq(2)
    list.item(1).not_nil!.text.should eq("b")
  end

  it "is returned from Qt" do
    root = File.join(Qt::Dir.temp_path, "qt5cr-string-list-#{Process.pid}")
    Dir.mkdir(root)
    begin
      %w[b.txt a.txt c.log].each { |name| File.touch(File.join(root, name)) }
      dir = Qt::Dir.new(root)
      names = dir.entry_list(["*.txt"], Qt::Dir::Filters::Files, Qt::Dir::SortFlags::Name)
      names.to_a.should eq(["a.txt", "b.txt"])
      dir.entry_list(Qt::Dir::Filters::Files).to_a.sort.should eq(["a.txt", "b.txt", "c.log"])
      dir.name_filters = ["*.log"]
      dir.name_filters.to_a.should eq(["*.log"])
    ensure
      Qt::Dir.new(root).remove_recursively
    end
  end

  it "has the QStringList methods" do
    list = Qt::StringList.from(["Banana", "apple", "cherry", "apple"])
    list.remove_duplicates.should eq(1)
    list.to_a.should eq(["Banana", "apple", "cherry"])
    list.sort(Qt::CaseSensitivity::CaseInsensitive) # In place
    list.to_a.should eq(["apple", "Banana", "cherry"])
    list.sort
    list.to_a.should eq(["Banana", "apple", "cherry"])

    list.filter("an").to_a.should eq(["Banana"])
    list.filter("AN", Qt::CaseSensitivity::CaseInsensitive).to_a.should eq(["Banana"])
    list.contains("apple").should be_true
    list.contains("APPLE").should be_false
    list.index_of("cherry").should eq(2)

    list.replace_in_strings("a", "4")
    list.to_a.should eq(["B4n4n4", "4pple", "cherry"])
    list.join("+").should eq("B4n4n4+4pple+cherry")
    list.remove_all("cherry").should eq(1)
    list.size.should eq(2)
    expect_raises(IndexError) { list[2] }
  end

  it "builds wrapped lists directly" do
    list = Qt::QList.of(String).from(["x", "y"])
    list.size.should eq(2)
    list << "z"
    list.to_a.should eq(["x", "y", "z"])
    list.join(", ").should eq("x, y, z")
  end
end

# `QPolygon` is a `QVector<QPoint>`, so its wrapper is an `Indexable(Qt::Point)`.
describe "QPolygon" do
  it "is a list of points" do
    polygon = Qt::Polygon.new
    polygon << Qt::Point.new(0, 0)
    polygon << Qt::Point.new(4, 0)
    polygon.size.should eq(2)
    polygon.to_a.should eq([Qt::Point.new(0, 0), Qt::Point.new(4, 0)])

    triangle = Qt::Polygon.new([Qt::Point.new(0, 0), Qt::Point.new(4, 0), Qt::Point.new(4, 4)])
    triangle.size.should eq(3)
    triangle[2].should eq(Qt::Point.new(4, 4))
    triangle.bounding_rect.should eq(Qt::Rect.new(0, 0, 5, 5))

    image = Qt::Image.new(8, 8, Qt::Image::Format::Rgb32)
    image.fill(Qt::GlobalColor::White)
    Qt::Painter.draw(image, &.draw_polygon(triangle))
    (image.pixel(4, 2) & 0xFFFFFF).should eq(0x000000) # On the outline
    (image.pixel(7, 7) & 0xFFFFFF).should eq(0xFFFFFF)
  end
end
