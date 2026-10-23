require "../spec_helper"

# qHash is bound as #q_hash and forwarded to #hash, toString to #to_s.
describe "hash and string conversion" do
  it "makes value types Hash keys and Set elements" do
    Qt::Point.new(1, 2).hash.should eq(Qt::Point.new(1, 2).hash)
    Qt::Point.new(1, 2).hash.should_not eq(Qt::Point.new(2, 1).hash)
    {Qt::Point.new(1, 2) => "a"}[Qt::Point.new(1, 2)].should eq("a")
    Set{Qt::Date.new(2024, 1, 15), Qt::Date.new(2024, 1, 15)}.size.should eq(1)
    Qt::Url.new("https://example.org/").q_hash(0).should eq(Qt::Url.new("https://example.org/").q_hash(0))
  end

  it "writes toString in to_s and inspect" do
    Qt::Date.new(2024, 1, 15).to_s.should eq(Qt::Date.new(2024, 1, 15).to_string)
    Qt::Url.new("https://example.org/").to_s.should eq("https://example.org/")
    Qt::Url.new("https://example.org/").inspect.should eq("#<Qt::Url https://example.org/>")
    "#{Qt::Uuid.new}".should eq("{00000000-0000-0000-0000-000000000000}")
  end
end
