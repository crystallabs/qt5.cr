module Qt
  class Application
    @argv : UInt8** = ARGV_UNSAFE
    @argc : Int32 = ARGC_UNSAFE

    def initialize
      @unwrap = Binding.bg_QApplication__CONSTRUCT_int_R_char_XX_int(pointerof(@argc), @argv, QT_VERSION)
      # Qt keeps a reference to `@argc` for the life of the application, which
      # `QCoreApplication::arguments` reads, so this wrapper must live as long.
      BindgenHelper.keep_alive(self)
      Qt.qt5cr_reset_numeric_locale
    end
  end
end
