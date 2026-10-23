require "../src/qt5"

# On how to create a timer to do things periodically.  Note that this timer is
# Qt native, it's not a Crystal `Fiber`.

# We create the application and a simple label for display
qApp = Qt::Application.new
counter_label = Qt::Label.new("Hey, watch this!  You want to!  Really!")
counter_label.window_title = "Tick Tock"
counter = 0

# Create the timer.
timer = Qt::Timer.new

# Connect to the timeout signal, which is emitted every interval tick
timer.on_timeout do
  counter += 1
  counter_label.text = "You've been staring for #{counter} seconds."
end

# We'll go with an interval of a second.  `Timer#start` also takes a
# `Time::Span`, so you should feel right at home with this:
timer.start(1.second)

# And now, start it!
counter_label.show
Qt::Application.exec
