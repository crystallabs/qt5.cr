require "../spec_helper"

# QSet<T> is an Enumerable(T). No wrapped Qt 5 method takes or returns one, so
# the sets are built directly.
describe "QSet" do
  it "builds a set from any Enumerable, dropping duplicates" do
    set = Qt::QSet.of(String).from(["a", "b", "a"])
    set.size.should eq(2)
    set.empty?.should be_false
    set.includes?("a").should be_true
    set.includes?("c").should be_false
    set.to_a.sort.should eq(["a", "b"])
  end

  it "adds, deletes and concatenates" do
    set = Qt::QSet.of(Int32).from([1, 2, 3])
    set << 4
    set.add(4)
    set.size.should eq(4)
    set.delete(2).should be_true
    set.delete(2).should be_false
    set.concat([7, 8, 1])
    set.to_a.sort.should eq([1, 3, 4, 7, 8])
  end

  it "iterates a snapshot while the set is modified" do
    set = Qt::QSet.of(Int32).from([1, 2, 3])
    seen = [] of Int32
    set.each do |value|
      seen << value
      set << value + 10
    end
    seen.sort.should eq([1, 2, 3])
    set.size.should eq(6)
    set.map { |value| value * 2 }.sort.should eq([2, 4, 6, 22, 24, 26])
  end
end
