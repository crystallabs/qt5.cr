module Qt
  class CoreApplication
    @argv : UInt8** = ARGV_UNSAFE
    @argc : Int32 = ARGC_UNSAFE

    # Creates the application with the program's own arguments, and starts
    # running fibers from its event loop (`Qt::Fibers`).
    def initialize
      @unwrap = Binding.bg_QCoreApplication__CONSTRUCT_int_R_char_XX_int(pointerof(@argc), @argv, QT_VERSION)
      Qt.qt5cr_application_created(self)
    end

    # Runs the event loop, with fibers (`Qt::Fibers.install`) however the
    # application was created.
    def self.exec : Int32
      Fibers.install
      previous_def
    end
  end

  class GuiApplication
    # Creates the application with the program's own arguments, and starts
    # running fibers from its event loop (`Qt::Fibers`).
    def initialize
      @unwrap = Binding.bg_QGuiApplication__CONSTRUCT_int_R_char_XX_int(pointerof(@argc), @argv, QT_VERSION)
      Qt.qt5cr_application_created(self)
    end
  end

  class Application
    # Creates the application with the program's own arguments, and starts
    # running fibers from its event loop (`Qt::Fibers`).
    def initialize
      @unwrap = Binding.bg_QApplication__CONSTRUCT_int_R_char_XX_int(pointerof(@argc), @argv, QT_VERSION)
      Qt.qt5cr_application_created(self)
    end
  end

  # :nodoc:
  def self.qt5cr_application_created(app : CoreApplication) : Nil
    # Qt keeps a reference to `@argc` for the life of the application, which
    # `QCoreApplication::arguments` reads, so this wrapper must live as long.
    BindgenHelper.keep_alive(app)
    qt5cr_reset_numeric_locale
    Fibers.install
  end
end
