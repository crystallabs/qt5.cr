require "../spec_helper"

struct SmallStruct
  property value : Int32

  def initialize(@value)
  end
end

struct BigStruct
  property a : Int64
  property b : Int64
  property c : Int8

  def initialize(@a, @b, @c)
  end
end

# Assert that the structures are sized the way we want
raise "SmallStruct is too big" if sizeof(SmallStruct) > Qt::Variant::INLINE_SIZE
raise "BigStruct is too small" if sizeof(BigStruct) <= Qt::Variant::INLINE_SIZE
# SIZE_MINUS_PTR = Qt::Variant::INLINE_SIZE - sizeof(Void*) # Crystal Issue #5427
SIZE_MINUS_PTR = Qt::Variant::INLINE_SIZE - 8

describe Qt::Variant do
  describe "#type_id" do
    it "returns the crystal type id" do
      Qt.variant(true).type_id.should eq(Bool.crystal_instance_type_id)
      Qt.variant(123).type_id.should eq(Int32.crystal_instance_type_id)
      Qt.variant("Hello").type_id.should eq(String.crystal_instance_type_id)
      Qt.variant(["One", "Two"]).type_id.should eq(Array(String).crystal_instance_type_id)
      Qt.variant({true, 1}).type_id.should eq(Tuple(Bool, Int32).crystal_instance_type_id)
    end
  end

  describe "#is_nil?" do
    context "on a nil object" do
      it "returns true" do
        Qt.variant(nil).is_nil?.should be_true
      end
    end

    context "on a non-nil object" do
      it "returns true" do
        Qt.variant(true).is_nil?.should be_false
        Qt.variant(false).is_nil?.should be_false
        Qt.variant("Hello").is_nil?.should be_false
      end
    end
  end

  describe "#is?" do
    context "with a single type" do
      it "checks for the type" do
        Qt.variant("string").is?(String).should be_true
        Qt.variant("string").is?(Int32).should be_false
        Qt.variant("string").is?(Nil).should be_false
      end

      it "works with Nil" do
        Qt.variant(nil).is?(String).should be_false
        Qt.variant(nil).is?(Int32).should be_false
        Qt.variant(nil).is?(Nil).should be_true
      end
    end

    context "with an union type" do
      it "checks for any of the types" do
        Qt.variant("string").is?(String | Int32).should be_true
        Qt.variant(123).is?(String | Int32).should be_true
        Qt.variant(nil).is?(String | Int32).should be_false
      end

      it "works with Nil" do
        # Safe > Sorry: Check that `T?` works same as `T | Nil`.
        Qt.variant("string").is?(String | Nil).should be_true
        Qt.variant("string").is?(String?).should be_true
        Qt.variant(nil).is?(String | Nil).should be_true
        Qt.variant(nil).is?(String?).should be_true
        Qt.variant(123456).is?(String | Nil).should be_false
        Qt.variant(123465).is?(String?).should be_false
      end
    end
  end

  describe "#to" do
    context "with the correct type" do
      it "returns the unpacked Reference" do
        value = Qt.variant("Hello").to(String)

        typeof(value).should eq(String) # We want it to be exactly a string
        value.should eq("Hello")
      end

      it "returns the unpacked small Value" do
        value = Qt.variant(12345).to(Int32)

        typeof(value).should eq(Int32)
        value.should eq(12345)
      end

      it "returns the unpacked big Value" do
        big = BigStruct.new(1i64, 2i64, 3i8)
        value = Qt.variant(big).to(BigStruct)

        typeof(value).should eq(BigStruct)
        value.should eq(big)
      end
    end

    context "with the incorrect type" do
      it "raises TypeCastError" do
        expect_raises(TypeCastError, /variant doesn't contain a Int32/i) do
          Qt.variant("Hello").to(Int32)
        end
      end
    end

    context "with a union type" do
      context "if one of the types match" do
        it "returns the value" do
          value = Qt.variant("Hello").to(String | Int32)
          typeof(value).should eq(String | Int32)
          value.should eq("Hello")
        end
      end

      context "if NONE of the types match" do
        it "raises TypeCastError" do
          expect_raises(TypeCastError, /variant doesn't contain/i) do
            Qt.variant("Hello").to(Int32 | Bool)
          end
        end
      end
    end

    context "nil behaviour" do
      it "returns nil if the variant contains nil" do
        Qt.variant(nil).to(Nil).should eq(nil)
        Qt.variant(nil).to(String | Nil).should eq(nil)
        Qt.variant(nil).to(String?).should eq(nil)
      end

      it "raises TypeCastError if the variant doesn't contain nil" do
        expect_raises(TypeCastError, "Variant doesn't contain a Nil") do
          Qt.variant("Hello").to(Nil)
        end

        expect_raises(TypeCastError, "Variant doesn't contain a (Int32 | Nil)") do
          Qt.variant("Hello").to(Int32 | Nil)
        end

        expect_raises(TypeCastError, "Variant doesn't contain a (Int32 | Nil)") do
          Qt.variant("Hello").to(Int32?)
        end
      end
    end
  end

  describe "#to?" do
    context "with the correct type" do
      it "returns the unpacked Reference" do
        value = Qt.variant("Hello").to?(String)
        typeof(value).should eq(String | Nil)
        value.should eq("Hello")
      end

      it "returns the unpacked small Value" do
        value = Qt.variant(12345).to?(Int32)

        typeof(value).should eq(Int32 | Nil)
        value.should eq(12345)
      end

      it "returns the unpacked big Value" do
        big = BigStruct.new(1i64, 2i64, 3i8)
        value = Qt.variant(big).to?(BigStruct)

        typeof(value).should eq(BigStruct | Nil)
        value.should eq(big)
      end
    end

    context "with the incorrect type" do
      it "returns nil" do
        value = Qt.variant(123456).to?(String)
        typeof(value).should eq(String | Nil)
        value.should eq(nil)
      end
    end

    context "with a union type" do
      context "if one of the types match" do
        it "returns the value" do
          value = Qt.variant("Hello").to?(String | Int32)
          typeof(value).should eq(String | Int32 | Nil)
          value.should eq("Hello")
        end
      end

      context "if NONE of the types match" do
        it "raises TypeCastError" do
          value = Qt.variant("Hello").to?(Int32 | Bool)
          typeof(value).should eq(Int32 | Bool | Nil)
          value.should eq(nil)
        end
      end
    end

    context "nil behaviour" do
      it "returns nil if the variant contains nil" do
        Qt.variant(nil).to?(Nil).should eq(nil)
        Qt.variant(nil).to?(String | Nil).should eq(nil)
        Qt.variant(nil).to?(String?).should eq(nil)
      end

      it "returns nil if the variant doesn't contain nil" do
        Qt.variant("Hello").to?(Nil).should eq(nil)
        Qt.variant("Hello").to?(Int32 | Nil).should eq(nil)
        Qt.variant("Hello").to?(Int32?).should eq(nil)
      end
    end
  end

  describe "packing behaviour" do
    it "inline size is >= size of a pointer" do
      (Qt::Variant::INLINE_SIZE >= sizeof(Void*)).should be_true
    end

    it "stores a Reference as pointer" do
      string = "I'm a reference"
      data = Qt.variant(string).to_unsafe
      string_ptr = Pointer(Void).new(string.object_id)

      data.type_id.should eq(string.crystal_type_id)
      data.data.pointer.should eq(string_ptr)
    end

    it "stores a generic Reference type as pointer" do
      ary = %w[one two three]
      data = Qt.variant(ary).to_unsafe
      ary_ptr = Pointer(Void).new(ary.object_id)

      data.type_id.should eq(ary.crystal_type_id)
      data.data.pointer.should eq(ary_ptr)
    end

    it "stores a small value inline" do
      value = SmallStruct.new(123456)
      data = Qt.variant(value).to_unsafe
      value_bytes = pointerof(value).as(UInt8*).to_slice(sizeof(SmallStruct))

      data.type_id.should eq(value.crystal_type_id)
      data.data.bytes.to_slice[0, sizeof(SmallStruct)].should eq(value_bytes)
    end

    it "stores a small generic value inline" do
      value = {1, 2}
      data = Qt.variant(value).to_unsafe
      value_bytes = pointerof(value).as(UInt8*).to_slice(sizeof({Int32, Int32}))

      data.type_id.should eq(value.crystal_type_id)
      data.data.bytes.to_slice[0, sizeof({Int32, Int32})].should eq(value_bytes)
    end

    it "stores up to the INLINE_SIZE inline" do
      value = StaticArray(UInt8, Qt::Variant::INLINE_SIZE).new(&.to_u8)
      data = Qt.variant(value).to_unsafe

      data.type_id.should eq(value.crystal_type_id)
      data.data.bytes.should eq(value)
    end

    it "stores a large value on the heap" do
      null = StaticArray(UInt8, SIZE_MINUS_PTR).new(0u8)

      value = BigStruct.new(1i64, 2i64, 3i8)
      data = Qt.variant(value).to_unsafe

      data.type_id.should eq(value.crystal_type_id)

      # Sanity check: Trailing inline bytes should be all-zero
      (data.data.bytes.to_slice + sizeof(Void*)).should eq(null.to_slice)
      data.data.pointer.should_not eq(Pointer(Void).null)
      data.data.pointer.as(BigStruct*).value.should eq(value)
    end

    it "stores a large generic value on the heap" do
      value = {"one", "two", "three"}
      data = Qt.variant(value).to_unsafe

      data.type_id.should eq(value.crystal_type_id)

      data.data.pointer.should_not eq(Pointer(Void).null)
      data.data.pointer.as({String, String, String}*).value.should eq(value)
    end
  end
end
