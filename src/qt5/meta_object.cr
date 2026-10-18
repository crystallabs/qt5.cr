module Qt
  class MetaObject
    # Invokes the slot or invokable method *member* of *object* by name,
    # without arguments: `Qt::MetaObject.invoke_method(button, "click")`.
    # Returns `false` when there's no such method.  The overloads taking
    # arguments are dropped, see `ext/meta_helper.hpp`.
    def self.invoke_method(object : Object, member : String, type : ConnectionType = ConnectionType::AutoConnection) : Bool
      Qt.qt5cr_invoke_method(object, member.to_unsafe, type)
    end
  end
end
