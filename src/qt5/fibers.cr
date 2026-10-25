# Crystal fibers in Qt's event loop.
#
# `Qt::Application.exec`, like `Qt::EventLoop#exec`, `Qt::Dialog#exec` or a
# waiting `process_events`, blocks the calling fiber in Qt's event loop.  On
# its own no other fiber would run until it returns: no `spawn`, `sleep`,
# `Channel`, socket or Crystal timer.  `Qt::Fibers` has Qt's loop drive
# Crystal's scheduler instead:
#
# * Crystal's event loop is a kqueue (macOS, BSD) or epoll (Linux) descriptor
#   that becomes readable when a fiber's IO, timer or wakeup from another
#   thread is ready.  `install` puts a `QSocketNotifier` on it, so Qt's loop
#   wakes up and runs the ready fibers (`pump`).
# * Before Qt's loop blocks waiting for events (`aboutToBlock`), a fiber made
#   runnable meanwhile, like one spawned from a slot, makes the descriptor
#   readable (`Crystal::EventLoop#interrupt`), so the notifier runs it.  The
#   fibers don't run from `aboutToBlock` itself: Cocoa's dispatcher emits it
#   from a run loop observer, and a nested `[NSApp run]` (a `QEventLoop#exec`
#   from a fiber) never gets going inside one.
#
# `pump` suspends the calling fiber, the one running Qt's loop, and resumes it
# only when no other fiber can run and no event is pending, the moment the
# scheduler would otherwise block in the event loop: the `run` of
# `Crystal::EventLoop::Polling` below hands back the idle fiber instead of
# blocking.  Qt's loop then waits for both Qt's events and Crystal's.  A nested
# Qt loop started from a fiber, a modal dialog say, pumps the same way; the
# idle fibers form a stack and the innermost returns first, like Qt's own
# nesting (an outer loop never runs while an inner one is suspended).
#
# Fibers that never wait, a `Fiber.yield` loop or two fibers passing a channel
# back and forth, would keep the idle fiber from returning and freeze Qt.  So
# after `slice` of fiber time, the scheduler resumes the idle fiber instead of
# the next runnable one, which is queued again, and interrupts Crystal's loop
# so that the notifier soon brings the fibers back: Qt's loop gets a turn
# every `slice` however busy the fibers are, like Crystal's event loop gets one
# whenever no fiber is runnable.
#
# Everything runs in the main thread, the default execution context's
# parallelism stays 1 (see main_thread.cr), and a Qt thread never calls into
# Crystal, so nothing here runs on one.  Blocking the fiber that runs Qt's
# loop blocks Qt's loop, as in C++: `spawn` instead of `sleep` in a slot.
#
# Compile with -Dqt5_without_fibers to leave Qt's loop alone: fibers then wait
# while it runs.  Crystal's polling event loops are needed (the defaults;
# `-Devloop=libevent` has no descriptor to watch) and so is either the
# execution context runtime (the default) or `-Dwithout_mt`.
module Qt
  module Fibers
    {% if flag?(:qt5_without_fibers) %}
      # Compiled with -Dqt5_without_fibers: nothing to install.
      def self.install : Nil
      end

      def self.installed? : Bool
        false
      end
    {% else %}
      {% unless Crystal::EventLoop.has_constant?("Kqueue") || Crystal::EventLoop.has_constant?("Epoll") %}
        {% raise "qt5.cr runs fibers from Qt's event loop by watching the descriptor of Crystal's kqueue or epoll event loop, which this build doesn't use: compile with -Dqt5_without_fibers to run Qt without fibers, see src/qt5/fibers.cr" %}
      {% end %}
      {% if flag?(:preview_mt) && !flag?(:execution_context) %}
        {% raise "qt5.cr runs fibers from Qt's event loop with the execution context runtime (the default) or with -Dwithout_mt, not with -Dpreview_mt: compile with -Dqt5_without_fibers to run Qt without fibers, see src/qt5/fibers.cr" %}
      {% end %}
      {% unless Crystal::EventLoop::Polling.has_method?("run") && (flag?(:without_mt) ? (Crystal::Scheduler.class.has_method?("reschedule") && Crystal::Scheduler.has_method?("resume")) : (::Fiber::ExecutionContext.class.has_method?("reschedule") && ::Fiber::ExecutionContext::Parallel::Scheduler.has_method?("resume"))) %}
        {% raise "qt5.cr runs fibers from Qt's event loop by overriding Crystal::EventLoop::Polling#run and the scheduler's resume, which this Crystal doesn't have: compile with -Dqt5_without_fibers to run Qt without fibers, see src/qt5/fibers.cr" %}
      {% end %}

      @@notifier : Notifier?
      @@about_to_block : SignalConnection?

      # How long the fibers run on end before Qt's loop gets a turn, when they
      # never wait.  Fibers that wait (`sleep`, a channel, IO) give Qt's loop
      # its turn at once.
      class_property slice : ::Time::Span = 4.milliseconds

      # Starts running fibers from Qt's event loop.  The application
      # constructors without arguments (`Qt::Application.new` and the
      # `Qt::CoreApplication` and `Qt::GuiApplication` ones) call this, and so
      # does the first `Qt::CoreApplication.exec`; calling it again does
      # nothing.  Needs the application object, as the event dispatcher of the
      # main thread must exist, and the current execution context must have a
      # parallelism of 1 (the default context does, unless resized).
      def self.install : Nil
        return if @@notifier

        unless dispatcher = AbstractEventDispatcher.instance
          raise "Qt::Fibers.install needs the application object: create Qt::Application first"
        end

        {% unless flag?(:without_mt) %}
          context = ::Fiber::ExecutionContext.current
          return unless context.is_a?(::Fiber::ExecutionContext::Parallel)
          unless context.capacity == 1
            raise "Qt::Fibers needs an execution context of parallelism 1, as Qt runs in one thread: #{context.name} has #{context.capacity}"
          end
        {% end %}

        @@notifier = Notifier.new(fd)
        @@about_to_block = dispatcher.on_about_to_block do
          Crystal::EventLoop.current.interrupt if pending?
        end
      end

      # Whether fibers run from Qt's event loop, see `install`.
      def self.installed? : Bool
        !@@notifier.nil?
      end

      # The descriptor of the current execution context's event loop, readable
      # when a fiber's IO, timer or wakeup is ready.
      def self.fd : Int32
        {% if Crystal::EventLoop.has_constant?("Kqueue") %}
          Crystal::EventLoop.current.as(Crystal::EventLoop::Kqueue).@kqueue.@kq
        {% else %}
          Crystal::EventLoop.current.as(Crystal::EventLoop::Epoll).@epoll.fd
        {% end %}
      end

      # Whether a fiber is runnable and waits for the current fiber to let it
      # run.
      def self.pending? : Bool
        {% if flag?(:without_mt) %}
          !::Thread.current.scheduler.@runnables.empty?
        {% else %}
          scheduler = ::Fiber::ExecutionContext::Scheduler.current
          return false unless scheduler.is_a?(::Fiber::ExecutionContext::Parallel::Scheduler)
          !scheduler.@runnables.empty? || !scheduler.execution_context.@global_queue.empty?
        {% end %}
      end

      # Runs the other fibers of the current execution context until all of
      # them wait, or for `slice`, then returns.  Ready events of Crystal's
      # event loop (IO, timers) are handled on the way, without waiting for
      # more.  Qt's event loop calls this when Crystal's event loop has
      # events; a long computation in a slot may call it as it would
      # `Qt::Application.process_events`.
      def self.pump : Nil
        Crystal::EventLoop.current.as(Crystal::EventLoop::Polling).qt_fibers_idle(::Fiber.current)
      end

      # A `QSocketNotifier` on the event loop's descriptor.  Qt delivers a
      # `SockAct` event when the descriptor is readable (the `activated`
      # signal isn't bound, its `QSocketDescriptor` argument being skipped).
      private class Notifier < SocketNotifier
        def initialize(fd : Int32)
          super(fd.to_i64, SocketNotifier::Type::Read)
        end

        protected def event(event : Event) : Bool
          if event.type == Event::Type::SockAct
            Fibers.pump
            true
          else
            super
          end
        end
      end
    {% end %}
  end
end

{% unless flag?(:qt5_without_fibers) %}
  abstract class Crystal::EventLoop
    # :nodoc:
    #
    # The idle fiber to resume instead of the next runnable one when it is
    # Qt's turn, see `Qt::Fibers`.  None here: only the polling loops idle.
    def qt_fibers_turn? : ::Fiber?
    end
  end

  abstract class Crystal::EventLoop::Polling
    # Fibers idling in Qt's event loop, with the time they started idling, see
    # `Qt::Fibers.pump`: the most recent one is resumed when the scheduler
    # would otherwise block here, or when it is Qt's turn.
    @qt_fibers_idle = [] of {::Fiber, ::Time::Instant}

    # The idle fiber the `run` below has just handed to the scheduler, which
    # is about to resume it: not a fiber to hold back for Qt's turn.
    @qt_fibers_resuming : ::Fiber?

    # Suspends *fiber*, the current one, until the scheduler has nothing to
    # run or it is Qt's turn.
    def qt_fibers_idle(fiber : ::Fiber) : Nil
      @qt_fibers_idle << {fiber, ::Time.instant}
      {% if flag?(:without_mt) %}
        Crystal::Scheduler.reschedule
      {% else %}
        ::Fiber::ExecutionContext.reschedule
      {% end %}
    end

    # Called by the scheduler before it resumes *fiber*: when the innermost
    # idle fiber has idled for `Qt::Fibers.slice`, returns it, popped, so the
    # scheduler resumes it instead and *fiber* waits; Crystal's loop is
    # interrupted so that Qt's loop returns to the fibers soon.
    def qt_fibers_turn?(fiber : ::Fiber) : ::Fiber?
      if fiber == @qt_fibers_resuming
        @qt_fibers_resuming = nil
        return
      end
      return unless idle = @qt_fibers_idle.last?
      return if ::Time.instant - idle[1] < Qt::Fibers.slice
      @qt_fibers_idle.pop
      interrupt
      idle[0]
    end

    {% if flag?(:without_mt) %}
      def run(blocking : Bool) : Bool
        if blocking && (idle = @qt_fibers_idle.last?)
          # Hand back the idle fiber instead of blocking, once the ready events
          # are processed and nothing came out of them.
          ready = false
          system_run(false) do |fiber|
            fiber.enqueue
            ready = true
          end
          unless ready
            @qt_fibers_idle.pop
            @qt_fibers_resuming = idle[0]
            idle[0].enqueue
          end
        else
          system_run(blocking, &.enqueue)
        end
        true
      end
    {% else %}
      def run(queue : ::Fiber::List*, blocking : Bool) : Nil
        if blocking && (idle = @qt_fibers_idle.last?)
          # Hand back the idle fiber instead of blocking, once the ready events
          # are processed and nothing came out of them.
          system_run(false) { |fiber| queue.value.push(fiber) }
          if queue.value.empty?
            @qt_fibers_idle.pop
            @qt_fibers_resuming = idle[0]
            queue.value.push(idle[0])
          end
        else
          system_run(blocking) { |fiber| queue.value.push(fiber) }
        end
      end
    {% end %}
  end

  {% if flag?(:without_mt) %}
    class Crystal::Scheduler
      protected def resume(fiber : ::Fiber) : Nil
        if idle = @event_loop.qt_fibers_turn?(fiber)
          enqueue(fiber)
          fiber = idle
        end
        previous_def(fiber)
      end
    end
  {% else %}
    class Fiber::ExecutionContext::Parallel::Scheduler
      protected def resume(fiber : ::Fiber) : Nil
        if fiber != @main_fiber && (idle = @event_loop.qt_fibers_turn?(fiber))
          @runnables.push(fiber)
          fiber = idle
        end
        previous_def(fiber)
      end
    end
  {% end %}
{% end %}
