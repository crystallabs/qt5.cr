require "../spec_helper"

# Qt threads must not call into Crystal (see the README), so these only
# construct, start and wait for threads running Qt code.
describe Qt::Thread do
  it "runs an event loop" do
    main = Qt::Thread.current_thread.not_nil!
    main.running?.should be_true
    Qt::Thread.ideal_thread_count.should be > 0

    thread = Qt::Thread.new
    thread.running?.should be_false
    thread.finished?.should be_false
    started = false
    thread.on_started { started = true }
    thread.start
    thread.running?.should be_true
    thread.interruption_requested?.should be_false
    thread.quit
    thread.wait.should be_true
    thread.finished?.should be_true
    thread.running?.should be_false
    # The started signal is queued to the main thread: delivered by the
    # event loop, not from the Qt thread.
    Qt::CoreApplication.process_events
    started.should be_true
    Qt::Thread.msleep(1)
  end
end

describe Qt::ThreadPool do
  it "is configured" do
    pool = Qt::ThreadPool.new
    pool.max_thread_count.should eq(Qt::Thread.ideal_thread_count)
    pool.max_thread_count = 2
    pool.max_thread_count.should eq(2)
    pool.active_thread_count.should eq(0)
    pool.expiry_timeout = 1000
    pool.expiry_timeout.should eq(1000)
    pool.wait_for_done.should be_true
    Qt::ThreadPool.global_instance.not_nil!.max_thread_count.should be > 0
  end
end

describe Qt::QMutex do
  it "locks" do
    mutex = Qt::QMutex.new
    mutex.recursive?.should be_false
    mutex.try_lock.should be_true
    mutex.try_lock(10).should be_false
    mutex.unlock
    mutex.lock
    mutex.unlock

    recursive = Qt::RecursiveMutex.new
    recursive.lock
    recursive.try_lock.should be_true
    recursive.unlock
    recursive.unlock
    Qt::QMutex.new(Qt::MutexRecursionMode::Recursive).recursive?.should be_true

    locker = Qt::MutexLocker.new(mutex)
    locker.mutex.not_nil!.to_unsafe.should eq(mutex.to_unsafe)
    mutex.try_lock.should be_false # Held by the locker
    locker.unlock
    mutex.try_lock.should be_true
    mutex.unlock

    lock = Qt::ReadWriteLock.new
    lock.try_lock_for_read.should be_true
    lock.try_lock_for_write.should be_false
    lock.unlock
    lock.lock_for_write
    lock.unlock
    Qt::WriteLocker.new(lock).read_write_lock.not_nil!.to_unsafe.should eq(lock.to_unsafe)
    lock.try_lock_for_read.should be_false
  end
end

describe Qt::Semaphore do
  it "counts" do
    semaphore = Qt::Semaphore.new(2)
    semaphore.available.should eq(2)
    semaphore.acquire
    semaphore.try_acquire(2).should be_false
    semaphore.try_acquire(1, 10).should be_true
    semaphore.available.should eq(0)
    semaphore.release(3)
    semaphore.available.should eq(3)
    releaser = Qt::SemaphoreReleaser.new(semaphore, 2)
    releaser.semaphore.not_nil!.to_unsafe.should eq(semaphore.to_unsafe)
    releaser.cancel.not_nil!.to_unsafe.should eq(semaphore.to_unsafe)

    condition = Qt::WaitCondition.new
    mutex = Qt::QMutex.new
    mutex.lock
    condition.wait(mutex, Qt::DeadlineTimer.new(1_i64)).should be_false
    condition.wait(mutex, 1_u64).should be_false # Milliseconds
    mutex.unlock
    condition.wake_all
  end
end

describe Qt::SharedMemory do
  it "creates and attaches a segment" do
    key = "qt5cr-spec-#{::Process.pid}"
    memory = Qt::SharedMemory.new(key)
    memory.key.should eq(key)
    memory.native_key.should_not eq("")
    memory.attached?.should be_false
    memory.create(64).should be_true
    memory.error.should eq(Qt::SharedMemory::SharedMemoryError::NoError)
    memory.attached?.should be_true
    memory.size.should be >= 64
    memory.lock.should be_true
    memory.data.as(UInt8*)[0] = 42_u8
    memory.unlock.should be_true

    other = Qt::SharedMemory.new(key)
    other.attach(Qt::SharedMemory::AccessMode::ReadOnly).should be_true
    other.const_data.as(UInt8*)[0].should eq(42)
    other.detach.should be_true
    memory.detach.should be_true
    memory.attached?.should be_false

    missing = Qt::SharedMemory.new("qt5cr-spec-missing-#{::Process.pid}")
    missing.attach.should be_false
    missing.error.should eq(Qt::SharedMemory::SharedMemoryError::NotFound)
    missing.error_string.should_not eq("")
  end
end

describe Qt::SystemSemaphore do
  it "acquires and releases" do
    key = "qt5cr-spec-#{::Process.pid}"
    semaphore = Qt::SystemSemaphore.new(key, 1, Qt::SystemSemaphore::AccessMode::Create)
    semaphore.error.should eq(Qt::SystemSemaphore::SystemSemaphoreError::NoError)
    semaphore.key.should eq(key)
    semaphore.acquire.should be_true
    semaphore.release.should be_true
  end
end
