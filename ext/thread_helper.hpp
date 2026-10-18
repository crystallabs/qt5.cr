// Qt 5's QRecursiveMutex derives privately from QMutex and re-exports lock,
// tryLock and unlock with using-declarations, which bindgen doesn't wrap, so
// these call them; see `Qt::RecursiveMutex` in src/qt5/recursive_mutex.cr.
#include <QtCore/QMutex>

void qt5cr_recursive_mutex_lock(QRecursiveMutex *mutex) {
  mutex->lock();
}

bool qt5cr_recursive_mutex_try_lock(QRecursiveMutex *mutex, int timeout) {
  return mutex->tryLock(timeout);
}

void qt5cr_recursive_mutex_unlock(QRecursiveMutex *mutex) {
  mutex->unlock();
}
