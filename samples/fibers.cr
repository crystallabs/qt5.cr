require "../src/qt5"

# Crystal fibers run while Qt's event loop runs: `Qt::Application.exec` has
# Qt's loop drive Crystal's scheduler (src/qt5/fibers.cr), so `spawn`, `sleep`,
# channels and sockets work in a Qt program as in any other.  Everything runs
# in the main thread, so a fiber updates widgets directly.

app = Qt::Application.new

window = Qt::Widget.new
window.window_title = "Fibers"
layout = Qt::VBoxLayout.new(window)
clock = Qt::Label.new("The clock fiber is starting...")
status = Qt::Label.new("Click to spawn a fiber.")
button = Qt::PushButton.new("Count down in a fiber")
layout.add_widget(clock)
layout.add_widget(status)
layout.add_widget(button)

# A fiber ticking with Crystal's `sleep`, no Qt timer needed.
spawn do
  loop do
    clock.text = Time.local.to_s("%H:%M:%S")
    sleep 1.second
  end
end

# A slot spawning a fiber: the slot returns at once and the fiber runs
# whenever Qt's loop idles, so the window stays responsive.  A `sleep` in the
# slot itself would freeze the window instead, as in C++.
button.on_clicked do
  spawn do
    5.downto(1) do |n|
      status.text = "#{n}..."
      sleep 500.milliseconds
    end
    status.text = "Done.  Click again!"
  end
end

# Fibers talk through channels as usual; this one feeds the status line.
channel = Channel(String).new
spawn do
  %w[Fibers channels sleep and\ sockets work\ with\ Qt].each do |word|
    channel.send(word)
    sleep 400.milliseconds
  end
  channel.close
end
spawn do
  while word = channel.receive?
    status.text = word
  end
  status.text = "Click to spawn a fiber."
end

window.show
Qt::Application.exec
