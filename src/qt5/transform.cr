module Qt
  # bindgen renders the `bool *invertible = nullptr` default of these as
  # `Bool*? = true`, which Crystal rejects on a call using the default, so
  # the methods are dropped and the helpers in `ext/matrix_helper.hpp` called.
  class Transform
    # Returns the inverse, and whether the transform was invertible at *invertible*.
    def inverted(invertible : Bool*? = nil) : Transform
      Qt.qt5cr_transform_inverted(self, invertible || Pointer(Bool).null)
    end
  end

  class Matrix
    # Returns the inverse, and whether the matrix was invertible at *invertible*.
    def inverted(invertible : Bool*? = nil) : Matrix
      Qt.qt5cr_matrix_inverted(self, invertible || Pointer(Bool).null)
    end
  end

  class Matrix4x4
    # Returns the inverse, and whether the matrix was invertible at *invertible*.
    def inverted(invertible : Bool*? = nil) : Matrix4x4
      Qt.qt5cr_matrix4x4_inverted(self, invertible || Pointer(Bool).null)
    end
  end
end
