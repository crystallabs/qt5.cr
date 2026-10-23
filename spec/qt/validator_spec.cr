require "../spec_helper"

# A validator written in Crystal: `validate` and `fixup` take the input by
# non-const reference in C++, so they return the new value with the result.
private class EvenValidator < Qt::Validator
  def validate(input : String, pos : Int32) : {Qt::Validator::State, String, Int32}
    return {Qt::Validator::State::Intermediate, input, pos} if input.empty?
    return {Qt::Validator::State::Invalid, input, pos} unless value = input.to_i?

    state = value.even? ? Qt::Validator::State::Acceptable : Qt::Validator::State::Intermediate
    {state, input, pos}
  end

  def fixup(input : String) : String
    ((input.to_i? || 0) // 2 * 2).to_s
  end
end

# `super` returns the tuple of the C++ implementation.
private class EvenSpinBox < Qt::SpinBox
  def validate(input : String, pos : Int32) : {Qt::Validator::State, String, Int32}
    state, input, pos = super
    state = Qt::Validator::State::Intermediate if state.acceptable? && input.to_i.odd?
    {state, input, pos}
  end
end

describe "out arguments" do
  it "return the input and position with the validator state" do
    validator = Qt::IntValidator.new(0, 100)
    validator.validate("42", 0).should eq({Qt::Validator::State::Acceptable, "42", 0})
    validator.validate("x", 0)[0].should eq(Qt::Validator::State::Invalid)
    validator.validate("", 0)[0].should eq(Qt::Validator::State::Intermediate)
  end

  it "run a Crystal validator from Qt" do
    edit = Qt::LineEdit.new
    edit.validator = EvenValidator.new
    edit.text = "42"
    edit.has_acceptable_input?.should be_true
    edit.text = "43"
    edit.has_acceptable_input?.should be_false

    # Through a wrapper of the validator Qt holds, dispatching virtually.
    validator = edit.validator.not_nil!
    validator.validate("8", 0).should eq({Qt::Validator::State::Acceptable, "8", 0})
    validator.validate("", 3)[0].should eq(Qt::Validator::State::Intermediate)
    validator.fixup("7").should eq("6")
  end

  it "pass the tuple of super through an override" do
    box = EvenSpinBox.new
    box.validate("4", 0)[0].should eq(Qt::Validator::State::Acceptable)
    box.validate("5", 0)[0].should eq(Qt::Validator::State::Intermediate)
    box.value = 4
    box.has_acceptable_input?.should be_true
    box.value = 5
    box.has_acceptable_input?.should be_false
  end

  it "return the line read through an out pointer" do
    stream = Qt::TextStream.new("one\ntwo".to_slice)
    stream.read_line_into.should eq({true, "one"})
    stream.read_line_into.should eq({true, "two"})
    stream.read_line_into.should eq({false, ""})
  end
end
