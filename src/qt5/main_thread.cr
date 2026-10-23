# Qt objects live in the OS thread that created them, and widgets in the main
# thread.  Crystal's execution contexts, the default runtime since Crystal
# 1.21, hand the scheduler of a thread blocked in a system call, like a slow
# `File.write`, to another thread, and the fiber resumes there: the main fiber
# leaves the main thread, Qt's timers fail ("Timers cannot be stopped from
# another thread") and creating a window deadlocks, waiting for the parked GUI
# thread.  Crystal has no way to pin a fiber to a thread (an `Isolated`
# context runs on a new thread, and widgets need the process's main thread),
# so this keeps the scheduler of a thread blocked in a system call where it is,
# as Crystal did before 1.21: the other fibers of the context wait for the
# call.  The default context runs with a parallelism of 1; don't resize it, Qt
# must be called from the main thread.  Compile with -Dwithout_mt to disable
# execution contexts instead, or with -Dqt5_allow_mt to leave them untouched.
{% if compare_versions(Crystal::VERSION, "1.21.0-0") >= 0 && (!flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context)) && !flag?(:qt5_allow_mt) %}
  {% unless Fiber::ExecutionContext::Scheduler.has_method?("detach_syscall?") %}
    {% raise "qt5.cr keeps the main fiber in the main thread by overriding Fiber::ExecutionContext::Scheduler#detach_syscall?, which this Crystal doesn't have: see src/qt5/main_thread.cr" %}
  {% end %}

  module Fiber::ExecutionContext::Scheduler
    # A thread blocked in a system call stays attached to its scheduler, so the
    # fiber resumes in the thread it left.
    protected def detach_syscall? : Bool
      false
    end
  end
{% end %}
