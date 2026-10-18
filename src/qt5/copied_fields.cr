module Qt
  # bindgen gives a copied structure of `kind: Struct` no property methods for
  # its public fields, as they're in `#to_unsafe` (and `kind: Class` with
  # `pass_by: Value` generates a constructor that doesn't compile), so these
  # structures of plain fields get them here.

  # An element of a `PainterPath`, see `PainterPath#element_at`.
  struct PainterPathElement
    def x : Float64
      @unwrap.x
    end

    def y : Float64
      @unwrap.y
    end

    def type : PainterPath::ElementType
      @unwrap.type
    end
  end
end
