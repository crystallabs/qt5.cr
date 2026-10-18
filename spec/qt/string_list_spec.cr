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
    list.item(1).text.should eq("b")
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
    list.remove_duplicates!.should eq(1)
    list.to_a.should eq(["Banana", "apple", "cherry"])
    list.sort!.to_a.should eq(["Banana", "apple", "cherry"])
    list.sort!(Qt::CaseSensitivity::CaseInsensitive).to_a.should eq(["apple", "Banana", "cherry"])

    list.filter("an").to_a.should eq(["Banana"])
    list.filter("AN", Qt::CaseSensitivity::CaseInsensitive).to_a.should eq(["Banana"])
    list.includes?("APPLE", Qt::CaseSensitivity::CaseInsensitive).should be_true
    list.includes?("APPLE").should be_false

    list.replace_in_strings!("a", "4").to_a.should eq(["4pple", "B4n4n4", "cherry"])
    list.join("+").should eq("4pple+B4n4n4+cherry")
  end

  it "builds wrapped lists directly" do
    list = Qt::QList.of(String).from(["x", "y"])
    list.size.should eq(2)
    list << "z"
    list.to_a.should eq(["x", "y", "z"])
    list.join(", ").should eq("x, y, z")
  end
end
