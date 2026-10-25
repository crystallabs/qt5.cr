require "../spec_helper"

private def single_shot(msec, &block : -> Nil)
  timer = Qt::Timer.new
  timer.single_shot = true
  timer.on_timeout { block.call }
  timer.start(msec)
  timer
end

describe Qt::Fibers do
  it "is installed by the application" do
    Qt::Fibers.installed?.should be_true
    Qt::Fibers.fd.should be >= 0
    Qt::Fibers.install # A second time does nothing
  end

  it "runs fibers while the application's event loop runs" do
    ticks = 0
    spawn do
      3.times do
        sleep 1.millisecond
        ticks += 1
      end
      Qt::Application.exit(3)
    end
    Qt::Application.exec.should eq(3)
    ticks.should eq(3)
  end

  it "runs a fiber spawned from a slot" do
    done = false
    timer = single_shot(0) do
      spawn do
        done = true
        Qt::Application.quit
      end
    end
    Qt::Application.exec
    done.should be_true
    timer.stop
  end

  it "wakes up for IO" do
    reader, writer = IO.pipe
    got = nil
    spawn do
      got = reader.gets
      Qt::Application.quit
    end
    spawn do
      sleep 2.milliseconds
      writer.puts "hello"
    end
    Qt::Application.exec
    got.should eq("hello")
    reader.close
    writer.close
  end

  it "passes channels between fibers" do
    channel = Channel(Int32).new
    sum = 0
    spawn do
      5.times do |i|
        channel.send(i)
        sleep 1.millisecond
      end
      channel.close
    end
    spawn do
      while value = channel.receive?
        sum += value
      end
      Qt::Application.quit
    end
    Qt::Application.exec
    sum.should eq(10)
  end

  it "keeps Qt timers and Crystal timers going together" do
    qt_ticks = 0
    crystal_ticks = 0
    timer = Qt::Timer.new
    timer.on_timeout { qt_ticks += 1 }
    timer.start(1)
    spawn do
      5.times do
        sleep 2.milliseconds
        crystal_ticks += 1
      end
      Qt::Application.quit
    end
    Qt::Application.exec
    timer.stop
    crystal_ticks.should eq(5)
    qt_ticks.should be > 0
  end

  it "runs fibers while Qt::EventLoop#exec runs" do
    loop = Qt::EventLoop.new
    woke = false
    spawn do
      sleep 1.millisecond
      woke = true
      loop.exit(5)
    end
    loop.exec.should eq(5)
    woke.should be_true
  end

  it "pumps a nested event loop run from a fiber, which returns first" do
    order = [] of Symbol
    inner_result = nil
    spawn do
      loop = Qt::EventLoop.new
      spawn do
        sleep 2.milliseconds
        order << :inner_quit
        loop.exit(7)
      end
      inner_result = loop.exec
      order << :inner_done
      spawn { order << :after_inner }
      sleep 1.millisecond
      Qt::Application.quit
    end
    Qt::Application.exec
    inner_result.should eq(7)
    order.should eq([:inner_quit, :inner_done, :after_inner])
  end

  it "delivers a Qt thread's signal to a waiting fiber" do
    channel = Channel(Nil).new(1)
    thread = Qt::Thread.new
    thread.on_finished { channel.send(nil) }
    spawn do
      channel.receive
      Qt::Application.quit
    end
    thread.start
    thread.quit
    Qt::Application.exec
    thread.wait.should be_true
  end

  it "pumps on request" do
    ran = false
    spawn { ran = true }
    Qt::Fibers.pending?.should be_true
    Qt::Fibers.pump
    ran.should be_true
    Qt::Fibers.pending?.should be_false
  end

  it "lets a slot block Qt's loop, as in C++, without losing fibers" do
    order = [] of Symbol
    slot_started = Channel(Nil).new(1)
    spawn do
      slot_started.receive
      order << :fiber
    end
    timer = single_shot(0) do
      order << :slot
      slot_started.send(nil)
      sleep 5.milliseconds # Blocks Qt's loop, the fiber runs meanwhile
      order << :slot_done
      Qt::Application.quit
    end
    Qt::Application.exec
    timer.stop
    order.should eq([:slot, :fiber, :slot_done])
  end
end

# Qt timer ticks while the fibers are busy, before they are, Qt's loop may
# tick on its own.
private def ticks_while_busy(duration, &busy : Time::Instant ->) : Int32
  qt_ticks = 0
  timer = Qt::Timer.new
  timer.on_timeout { qt_ticks += 1 }
  timer.start(1)
  ticks_before = 0
  ticks_after = 0
  spawn do
    ticks_before = qt_ticks
    busy.call(Time.instant + duration)
    ticks_after = qt_ticks
    Qt::Application.quit
  end
  Qt::Application.exec
  timer.stop
  ticks_after - ticks_before
end

describe "Qt::Fibers.slice" do
  it "gives Qt's loop a turn while fibers only yield" do
    # Long enough for a loaded machine to deliver a few 1 ms timer ticks.
    ticks = ticks_while_busy(200.milliseconds) do |deadline|
      other = spawn do
        while Time.instant < deadline
          Fiber.yield
        end
      end
      while Time.instant < deadline
        Fiber.yield
      end
    end
    ticks.should be >= 3
  end

  it "gives Qt's loop a turn while fibers pass a channel back and forth" do
    rounds = 0
    ticks = ticks_while_busy(200.milliseconds) do |deadline|
      ping = Channel(Int32).new
      pong = Channel(Int32).new
      spawn do
        while ping.receive?
          pong.send(1)
        end
      end
      while Time.instant < deadline
        ping.send(rounds)
        rounds += pong.receive
      end
      ping.close
    end
    rounds.should be > 0
    ticks.should be >= 3
  end

  it "is how long busy fibers keep Qt's loop waiting" do
    Qt::Fibers.slice.should eq(4.milliseconds)
    Qt::Fibers.slice = 1.second
    ticks = ticks_while_busy(30.milliseconds) do |deadline|
      while Time.instant < deadline
        Fiber.yield
      end
    end
    ticks.should eq(0)
  ensure
    Qt::Fibers.slice = 4.milliseconds
  end
end
