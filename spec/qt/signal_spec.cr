require "../spec_helper"

# Qt deprecated some overloads of these signals.  The others must be wrapped.
describe "signals with deprecated overloads" do
  it "QSpinBox#value_changed(Int32)" do
    spin_box = Qt::SpinBox.new
    values = [] of Int32
    spin_box.on_value_changed { |value| values << value }
    spin_box.value = 42
    values.should eq([42])
  end

  it "QComboBox#current_index_changed(Int32)" do
    combo_box = Qt::ComboBox.new
    indices = [] of Int32
    combo_box.on_current_index_changed { |index| indices << index }
    combo_box.add_item "first"
    combo_box.add_item "second"
    combo_box.current_index = 1
    indices.should eq([0, 1])
  end
end
