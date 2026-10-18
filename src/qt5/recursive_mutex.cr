module Qt
  # Qt 5's `QRecursiveMutex` derives privately from `QMutex` and re-exports
  # `lock`, `tryLock` and `unlock` with using-declarations, which bindgen
  # doesn't wrap, so the helpers in `ext/thread_helper.hpp` call them.
  class RecursiveMutex
    # Locks the mutex, waiting for another thread to unlock it if needed.
    def lock : Void
      Qt.qt5cr_recursive_mutex_lock(self)
    end

    # Tries to lock the mutex, waiting up to *timeout* milliseconds.
    def try_lock(timeout : Int32 = 0) : Bool
      Qt.qt5cr_recursive_mutex_try_lock(self, timeout)
    end

    # Unlocks the mutex.
    def unlock : Void
      Qt.qt5cr_recursive_mutex_unlock(self)
    end
  end
end
