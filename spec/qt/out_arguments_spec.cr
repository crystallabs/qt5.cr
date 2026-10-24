require "../spec_helper"

# A `bool *ok`, `int *` or `int &` a method writes through is an out argument,
# returned with the result: `builtin_out_arguments` in qt.yml.  Pointers to
# bytes and characters, and the arrays listed under `out_arguments:` in
# config/methods.yml, stay pointers.

describe "built-in out arguments" do
  it "returns a bool *ok with the result" do
    locale = Qt::Locale.new("en_US")
    locale.to_int("42").should eq({42, true})
    value, ok = locale.to_int("forty-two")
    value.should eq(0)
    ok.should be_false
  end

  it "returns the values of several out pointers" do
    Qt::Date.new(2026, 10, 24).get_date.should eq({2026, 10, 24})
    Qt::Color.new(10, 20, 30).get_rgb.should eq({10, 20, 30, 255})
    Qt::Rect.new(1, 2, 3, 4).get_rect.should eq({1, 2, 3, 4})
  end

  it "returns an out pointer with the result of a method taking other arguments" do
    inverse, invertible = Qt::Transform.from_translate(3.0, 4.0).inverted
    inverse.dx.should eq(-3.0)
    invertible.should be_true
  end

  it "leaves a pointer to an array alone" do
    values = StaticArray(Float32, 16).new(0.0_f32)
    Qt::Matrix4x4.new.copy_data_to(values.to_unsafe)
    values[0].should eq(1.0_f32)
    values[1].should eq(0.0_f32)
  end
end
