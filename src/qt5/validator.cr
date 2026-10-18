module Qt
  # `QValidator::validate` and `fixup` take the input by non-const reference,
  # which bindgen can't pass a `String` by, so the helpers in
  # `ext/validator_helper.hpp` call them on a copy.  Validators can't be
  # written in Crystal for the same reason: as the pure virtual `validate` is
  # dropped, bindgen skips the C++ subclass.
  class Validator
    # Returns the state of *input*, with the cursor at *pos*.
    def validate(input : String, pos : Int32 = 0) : State
      Qt.qt5cr_validator_validate(self, input, pos)
    end

    # Returns *input* fixed up to be acceptable, if the validator can.
    def fixup(input : String) : String
      Qt.qt5cr_validator_fixup(self, input)
    end
  end
end
