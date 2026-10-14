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

    # Constructs a Variant from the given value.  You can also use `Qt.variant`
    # for a shorter notation.
    def initialize(@data : Binding::CrystalVariant)
    end

    # :ditto:
    def initialize(variant : Variant)
      @data = variant.to_unsafe
    end

    # :ditto:
    def initialize(value)
      @data = self.class.pack(value)
    end

    def to_unsafe : Binding::CrystalVariant
      @data
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
  def self.variant(value) : Variant
    Variant.new(value)
  end
end
