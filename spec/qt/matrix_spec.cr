require "../spec_helper"

describe Qt::Matrix3x3 do
  it "is a QGenericMatrix typedef" do
    m = Qt::Matrix3x3.new
    m.identity?.should be_true
    m.fill(2.0_f32)
    m.identity?.should be_false
    m.set_to_identity
    m.identity?.should be_true
  end

  it "backs Matrix4x4#normal_matrix and Quaternion#to_rotation_matrix" do
    Qt::Matrix4x4.new.normal_matrix.identity?.should be_true
    Qt::Quaternion.new.to_rotation_matrix.identity?.should be_true
  end

  it "has operators" do
    a = Qt::Matrix3x3.new
    b = Qt::Matrix3x3.new
    (a == b).should be_true
    a.add!(b)
    (a == b).should be_false
    a.call(0, 0).value.should eq(2.0_f32)
    a.mul!(0.5_f32)
    (a == b).should be_true
    a.transposed.identity?.should be_true
  end
end
