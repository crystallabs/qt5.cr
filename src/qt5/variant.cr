module Qt
  lib Binding
    VARIANT_INLINE_SIZE = Variant::INLINE_SIZE

    union CrystalVariantData
      # bytes : UInt8[Variant::INLINE_SIZE] # Issue crystal/#5426
      bytes : UInt8[VARIANT_INLINE_SIZE]
      pointer : Void*
    end

    # Mirrored from ext/converters.hpp, "struct CrystalVariant"
    @[Packed]
    struct CrystalVariant
      type_id : Int32           # Crystal type id
      data : CrystalVariantData # Data
    end
  end

  # Wraps a `QVariant`.  A `QVariant`, in C++/Qt, is a generic container type
  # intended to host any kind of variable.
  #
  # **To construct** write `Qt.variant(value)` or `Qt::Variant.new(value)`.
  #
  # To work with the value in a `Variant` you have to **unpack the value**
  # using `#to`.  Please read on for clarification.
  #
  # You should only use `Variant` to interact with Qt.  It's quite heavy in
  # resources used compared to Crystals union types.  Prefer Crystal types
  # over using `Variant` in your code.
  #
  # ## Differences to QVariant
  #
  # This structure mimics QVariant in that it provides a generic container
  # capable of storing anything.  Unlike QVariant the `#to` method never
  # attempts to cast data types.  Also, as noted, `#to` are type-safe in the
  # Crystal sense: If the variant doesn't contain what `#to` asked for it
  # raises.  QVariant would try to return a default-constructed instance of
  # the type. **We never do implicit cast and are type-safe**.
  #
  # Developers coming from C++/Qt may also enjoy that you don't have to register
  # your own types to Qt anymore.  It just works!  See below for samples.
  #
  # ## Conversion to and from Qt
  #
  # Values of the types Qt knows itself are passed to Qt as the native
  # `QVariant` type, so Qt can display, sort and store them, and are unpacked
  # from Qt's values: `Nil` (an invalid `QVariant`), `Bool`, `Int32`, `UInt32`,
  # `Int64`, `UInt64`, `Float32`, `Float64`, `Char` (`QChar`), `String`,
  # `Bytes` (`QByteArray`), `Array(String)` and `StringList` (`QStringList`,
  # unpacked as `Array(String)`), `Point`, `PointF`, `Size`, `SizeF`, `Rect`
  # and `RectF`.  Qt's other integer types unpack as the `Int32`, `UInt32`,
  # `Int64` or `UInt64` of their size, see `Tag`.
  #
  # ```
  # model.set_data(index, Qt.variant("x"))    # A QString in the model
  # model.data(index).to(String)              # => "x"
  # settings.value("list").to?(Array(String)) # A QStringList Qt loaded
  # ```
  #
  # Any other Crystal value is wrapped as is, for the round trip through Qt.
  # Conversely a `QVariant` of a Qt type without a mapping, like a `QColor`,
  # is unpacked as *unknown*: not `#is_nil?`, but `#is?` nothing and `#to?`
  # returns `nil`.  It keeps the `QVariant`, so handing it back to Qt works:
  # `label.set_property("palette", other_label.property("palette"))`.
  #
  # ## Code sample
  #
  # ```
  # # You can construct a Variant yourself:
  # my_variant = Qt.variant("Hello, Crystal/Qt")
  #
  # # Qt::Variant mimics the Crystal casting API with slightly different names:
  # if my_variant.is?(String) # is? instead of is_a?
  #   # my_variant here is still a Qt::Variant!
  #
  #   # Instead, use the if-var notation like this:
  # elsif my_string = my_variant.to?(String)
  #   puts my_string # Still will work however
  # end
  #
  # # If you're sure of the type, you can safely cast it using #to:
  # my_string = my_variant.to(String)
  # Raises TypeCastError if `my_variant` is not a String - Just like #as would
  # ```
  #
  # ## Union types
  #
  # The methods `#is?`, `#to` and `#to?` also allow you to use union types:
  #
  # ```
  # # This variant will contain a String or an Int32 at random:
  # my_variant = Qt.variant(rand > 0.5 ? "Hello" : 123)
  # my_variant.is?(String | Int32) # => true
  # my_variant.is?(String)         # => Could be true or false
  # my_variant.is?(Int32)          # => Could be true or false
  #
  # # But you can use #to just like you would #as
  # pp my_variant.to(String | Int32)
  #
  # # Same goes for #to?
  # pp my_variant.to?(String | Int32) # Union types are fine!
  # pp my_variant.to?(String)         # As are single types of course
  # pp my_variant.to?(Int32)
  # ```
  #
  # ## Handling `nil`
  #
  # `nil` is treated as a normal value, just like in Crystal.  It is not
  # special.  Calling `#to` with the `Nil` type will only return `nil` if the
  # variant contains a nil.
  #
  # ```
  # variant = Qt.variant(123) # A variant containing an Int32
  #
  # # Raises TypeCastError: Int32 is neither String nor Nil
  # variant.to(String | Nil)
  #
  # # Returns nil: Int32 is neither String nor Nil
  # variant.to?(String | Nil)
  #
  # # Behaviour of a nil-containing variant:
  # nil_variant = Qt.variant(nil)
  # nil_variant.is_nil?           # => true
  # nil_variant.to(String | Nil)  # => nil
  # nil_variant.to?(String | Nil) # => nil
  # ```
  struct Variant
    # Max size of values to be inlined into the wrapper structure.  Values
    # exceeding this value will be transparently stored on the heap.
    INLINE_SIZE = 16 # sizeof(Void*) * 2

    # ^ That is supposed to be double the size of a pointer, but type notation
    #   don't accept constnat calculations yet.  So hardcode it for now.
    #   Tracking issue: Crystal issue #5427

    # Tags, in `Binding::CrystalVariant#type_id`, of values exchanged with Qt
    # in their native Qt form, see `#to_unsafe`.  Negative, as Crystal type
    # ids are positive.  `nil` is `Nil.crystal_instance_type_id`, which is 0.
    #
    # Mirrored from ext/converters.hpp, "struct CrystalVariant".
    enum Tag : Int32
      Unknown    =  -1 # A Qt type without a Crystal mapping.  A pointer to a GC-allocated copy of the QVariant, or null.
      Bool       =  -2 # bool, in bytes[0]
      Int32      =  -3 # int, inline
      UInt32     =  -4 # unsigned int, inline
      Int64      =  -5 # qlonglong, inline
      UInt64     =  -6 # qulonglong, inline
      Float32    =  -7 # float, inline
      Float64    =  -8 # double, inline
      Char       =  -9 # QChar, as a UTF-32 code point in a UInt32, inline
      String     = -10 # QString, as a CrystalString of UTF-8, inline
      Bytes      = -11 # QByteArray, as a CrystalString of the raw bytes, inline
      StringList = -12 # QStringList, a pointer to a GC-allocated QList<QString>
      Point      = -13 # QPoint, inline
      PointF     = -14 # QPointF, inline
      Size       = -15 # QSize, inline
      SizeF      = -16 # QSizeF, inline
      Rect       = -17 # QRect, inline
      RectF      = -18 # QRectF, a pointer to a GC-allocated copy
    end

    # Constructs a Variant from a `Binding::CrystalVariant` received from Qt,
    # unpacking a value Qt exchanged in its native form (see `Tag`).
    def initialize(data : Binding::CrystalVariant)
      @data = Variant.normalize(data)
    end

    # :ditto:
    def initialize(variant : Variant)
      @data = variant.@data
    end

    # :ditto:
    def initialize(value)
      @data = self.class.pack(value)
    end

    # The `Binding::CrystalVariant` passed to Qt.  A value of a type Qt knows
    # (see `Tag`) is tagged for `crystal_to_qvariant` to build the native
    # `QVariant` of it, so Qt can display, sort and store it.  Any other value
    # is wrapped as is.  The data of a tagged value belongs to this variant,
    # which the caller keeps alive while Qt copies it.
    def to_unsafe : Binding::CrystalVariant
      case @data.type_id
      when ::Bool.crystal_instance_type_id
        Variant.tagged(Tag::Bool, Variant.unpack_type(@data, ::Bool))
      when ::Int32.crystal_instance_type_id
        Variant.tagged(Tag::Int32, Variant.unpack_type(@data, ::Int32))
      when ::UInt32.crystal_instance_type_id
        Variant.tagged(Tag::UInt32, Variant.unpack_type(@data, ::UInt32))
      when ::Int64.crystal_instance_type_id
        Variant.tagged(Tag::Int64, Variant.unpack_type(@data, ::Int64))
      when ::UInt64.crystal_instance_type_id
        Variant.tagged(Tag::UInt64, Variant.unpack_type(@data, ::UInt64))
      when ::Float32.crystal_instance_type_id
        Variant.tagged(Tag::Float32, Variant.unpack_type(@data, ::Float32))
      when ::Float64.crystal_instance_type_id
        Variant.tagged(Tag::Float64, Variant.unpack_type(@data, ::Float64))
      when ::Char.crystal_instance_type_id
        Variant.tagged(Tag::Char, Variant.unpack_type(@data, ::Char).ord.to_u32)
      when ::String.crystal_instance_type_id
        Variant.tagged(Tag::String, Converter::QString.wrap(Variant.unpack_type(@data, ::String)))
      when ::Bytes.crystal_instance_type_id
        Variant.tagged(Tag::Bytes, Converter::QByteArray.wrap(Variant.unpack_type(@data, ::Bytes)))
      when ::Array(::String).crystal_instance_type_id
        list = StringList.from(Variant.unpack_type(@data, ::Array(::String)))
        Variant.tagged(Tag::StringList, list.to_unsafe.as(Void*))
      when StringList.crystal_instance_type_id
        Variant.tagged(Tag::StringList, Variant.unpack_type(@data, StringList).to_unsafe.as(Void*))
      when Point.crystal_instance_type_id
        Variant.tagged(Tag::Point, Variant.unpack_type(@data, Point).to_unsafe)
      when PointF.crystal_instance_type_id
        Variant.tagged(Tag::PointF, Variant.unpack_type(@data, PointF).to_unsafe)
      when Size.crystal_instance_type_id
        Variant.tagged(Tag::Size, Variant.unpack_type(@data, Size).to_unsafe)
      when SizeF.crystal_instance_type_id
        Variant.tagged(Tag::SizeF, Variant.unpack_type(@data, SizeF).to_unsafe)
      when Rect.crystal_instance_type_id
        Variant.tagged(Tag::Rect, Variant.unpack_type(@data, Rect).to_unsafe)
      when RectF.crystal_instance_type_id
        Variant.tagged(Tag::RectF, Variant.boxed(Variant.unpack_type(@data, RectF).to_unsafe))
      else
        @data
      end
    end

    # Returns the type id of the wrapped object.
    def type_id : Int32
      @data.type_id
    end

    # Returns `true` if this variant contains `nil`.
    def is_nil? : Bool
      @data.type_id == nil.crystal_type_id
    end

    # Does this variant contain a value of *type*?
    # This method is like `#is_a?`, except that the compiler won't enforce it!
    def is?(type : T.class) : Bool forall T
      {% if T.union? %}
        {% for inner in T.union_types %}
          return true if @data.type_id == {{ inner }}.crystal_instance_type_id
        {% end %}

        false
      {% else %}
        @data.type_id == type.crystal_instance_type_id
      {% end %}
    end

    # Unpacks a value of *type* from the variant.  If the variant doesn't
    # contain a *type*, a `TypeCastError` is raised.
    #
    # This method is like the `#as` cast method.
    def to(type : T.class) : T forall T
      {% begin %}
        Variant.unpack(@data, Union({{ T.is_a?(Path) ? T.resolve : T }})) do
          raise TypeCastError.new("Variant doesn't contain a #{T}")
        end
      {% end %}
    end

    # Unpacks a value of *type* from the variant.  If the variant doesn't
    # contain a *type*, `nil` is returned.
    #
    # This method is like the `#as?` cast method.
    def to?(type : T.class) : T? forall T
      {% begin %}
        Variant.unpack(@data, Union({{ T.is_a?(Path) ? T.resolve : T }})) do
          nil
        end
      {% end %}
    end

    # Helper macro to unpack the (possibly union) *type* from *data*.
    # Does type checks.  If *type* does not match, it'll yield.
    macro unpack(data, type)
      {% type = type.type_vars[0] if type.is_a?(Generic) %}
      {% type = type.resolve if type.is_a?(Path) %}
      {% if type.is_a?(Union) %}
        case {{ data }}.type_id
          {% for inner in type.types %}
          when {{ inner }}.crystal_instance_type_id
            Variant.unpack_type({{ data }}, {{ inner }})
          {% end %}
        else
          {{ yield }}
        end
      {% else %}
        if {{ data }}.type_id == {{ type }}.crystal_instance_type_id
          Variant.unpack_type({{ data }}, {{ type }})
        else
          {{ yield }}
        end
      {% end %}
    end

    # Helper macro to unpack a single *type* from the *data*.  This macro
    # doesn't do checks.
    macro unpack_type(data, type)
      {% type = type.resolve if type.is_a?(Path) %}
      {% kind_type = type.is_a?(Generic) ? type.name.resolve : type %}
      {% if kind_type < Reference %}
        {{ data }}.data.pointer.as({{ type }})
      {% else %} # Value branch
        if sizeof({{ type }}) > INLINE_SIZE
          {{ data }}.data.pointer.as({{ type }}*).value
        else
          {{ data }}.data.bytes.to_unsafe.as({{ type }}*).value
        end
      {% end %}
    end

    # Repacks *data* received from Qt, if it holds a value in its native Qt
    # form (see `Tag`), as the Crystal value, like `.pack` would.  Returns
    # anything else, including an unknown value, as it is.
    protected def self.normalize(data : Binding::CrystalVariant) : Binding::CrystalVariant
      return data unless tag = Tag.from_value?(data.type_id)

      case tag
      in .unknown?     then data
      in .bool?        then pack(inlined(data, ::Bool))
      in .int32?       then pack(inlined(data, ::Int32))
      in .u_int32?     then pack(inlined(data, ::UInt32))
      in .int64?       then pack(inlined(data, ::Int64))
      in .u_int64?     then pack(inlined(data, ::UInt64))
      in .float32?     then pack(inlined(data, ::Float32))
      in .float64?     then pack(inlined(data, ::Float64))
      in .char?        then pack(inlined(data, ::UInt32).chr)
      in .string?      then pack(Converter::QString.unwrap(inlined(data, Binding::CrystalString)))
      in .bytes?       then pack(Converter::QByteArray.unwrap(inlined(data, Binding::CrystalString)))
      in .string_list? then pack(StringList.new(unwrap: data.data.pointer.as(Binding::ContainerQListQString*)).to_a)
      in .point?       then pack(Point.new(unwrap: inlined(data, Binding::QPoint)))
      in .point_f?     then pack(PointF.new(unwrap: inlined(data, Binding::QPointF)))
      in .size?        then pack(Size.new(unwrap: inlined(data, Binding::QSize)))
      in .size_f?      then pack(SizeF.new(unwrap: inlined(data, Binding::QSizeF)))
      in .rect?        then pack(Rect.new(unwrap: inlined(data, Binding::QRect)))
      in .rect_f?      then pack(RectF.new(unwrap: data.data.pointer.as(Binding::QRectF*).value))
      end
    end

    # The value of *type* stored inline in *data*.
    private def self.inlined(data : Binding::CrystalVariant, type : T.class) : T forall T
      data.data.bytes.to_unsafe.as(T*).value
    end

    # A `Binding::CrystalVariant` of *tag* holding *value* inline.
    protected def self.tagged(tag : Tag, value : T) : Binding::CrystalVariant forall T
      wrapper = Binding::CrystalVariant.new(type_id: tag.value)
      value_slice = pointerof(value).as(UInt8*).to_slice(sizeof(T))
      wrapper.data.bytes.to_slice.copy_from(value_slice)
      wrapper
    end

    # A pointer to a GC-allocated copy of *value*, for the tags holding one.
    protected def self.boxed(value : T) : Void* forall T
      ptr = Pointer(T).malloc(1)
      ptr.value = value
      ptr.as(Void*)
    end

    # See `Qt.variant`.  Creates a `Binding::CrystalVariant`.
    def self.pack(value : Reference) : Binding::CrystalVariant
      ptr = Pointer(Void).new(value.object_id)
      Binding::CrystalVariant.new(
        type_id: value.crystal_type_id,
        data: Binding::CrystalVariantData.new(pointer: ptr),
      )
    end

    # :ditto:
    def self.pack(value : Value) : Binding::CrystalVariant
      wrapper = Binding::CrystalVariant.new(type_id: value.crystal_type_id)

      if sizeof(typeof(value)) > INLINE_SIZE
        # If too large for inlining, copy to the heap.
        ptr = Pointer(typeof(value)).malloc
        ptr.copy_from(pointerof(value), count: 1)
        wrapper.data.pointer = ptr.as(Void*)
      else # Small enough to inline!
        value_slice = pointerof(value).as(UInt8*).to_slice(sizeof(typeof(value)))
        wrapper.data.bytes.to_slice.copy_from(value_slice)
      end

      wrapper
    end
  end

  # Helper method to quickly build `Qt::Variant` instances from a *value*.  You
  # can pass anything as *value*:
  #
  # ```
  # Qt.variant("Hello")                     # A string
  # Qt.variant(123)                         # An integer
  # Qt.variant(MyCustomType.new)            # An instance of your type
  # Qt.variant(rand > 0.5 ? "String" : 123) # Anything you can think of
  # ```
  #
  # See `Variant` for the types Qt itself understands.
  def self.variant(value) : Variant
    Variant.new(value)
  end
end
