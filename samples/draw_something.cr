require "../src/qt5"

# The draw area widget.  We need a custom Widget to display an area to draw in.
class DrawArea < Qt::Widget
  def initialize(*args)
    super # Call this first!

    # We're using @image as backing store of the picture the user is drawing.
    @image = Qt::Image.new(500, 500, Qt::Image::Format::Argb32)
    @image.fill Qt::GlobalColor::White

    @brush = Qt::Brush.new(Qt::GlobalColor::Black)
    @last_pos = Qt::Point.new

    self.accept_drops = true
    resize(500, 500) # Resize the widget to the @image size.
  end

  def paint_event(_evt)
    # This event is called whenever the window needs to be redrawn, as
    # determined by Qt.  We create a Qt::Painter and simply draw our image at
    # the top-left corner of the widget itself.
    Qt::Painter.draw(self) do |p|
      p.draw_image Qt::Point.new(0, 0), @image
    end
  end

  def mouse_press_event(evt)
    # Called by Qt when the user pressed a mouse button.  We don't care which
    # one for this.  Just store the current position.
    @last_pos = evt.pos
  end

  def mouse_move_event(evt)
    # Called by Qt when the user pressed (and holds) a mouse button, and begins
    # moving around.  In this case, we draw a line from the last position to the
    # current position on our @image, and then remember the current position as
    # @last_pos.
    Qt::Painter.draw(@image) do |p|
      p.brush = @brush
      p.draw_line(@last_pos, evt.pos)
    end

    @last_pos = evt.pos

    # Also tell Qt that our widget changed, and thus needs an update.  Qt will
    # schedule a redraw for us in the near future.
    update
  end

  # We also allow the user to Drag&Drop a image file onto the draw area to load
  # it!  For this to work, you have to accept the proposal in the
  # `#drag_enter_event`...
  def drag_enter_event(evt)
    # We only care about files, not plain image data.
    evt.accept_proposed_action if evt.mime_data.has_urls?
  end

  # This event is *only* called if you accepted the proposal!  The user let go
  # and thus, we'll open the file.
  def drop_event(evt)
    list = evt.mime_data.urls # Might be many, but we only care about the first
    return if list.empty?     # Sanity check: We did get any URLs, right?
    # Qt transmits URLs, but we want a local file path instead.
    load list.first.to_local_file
  end

  # Loads an image at *path* and replaces the current image with it.
  def load(path)
    @image.load(path)
    resize(@image.width, @image.height)
  end

  # Saves the current image at *path*.  Qt will figure out a type on its own.
  # If the *path* ends with ".jpg", it will be a JPEG, etc.
  def save(path)
    @image.save(path)
  end
end

# Now build the user interface
app = Qt::Application.new
window = Qt::MainWindow.new
draw_area = DrawArea.new
window.window_title = "Draw Something!"
window.central_widget = draw_area

# Add a File menu with a Open, Save and Quit action.
file_menu = window.menu_bar.add_menu("File")
open_action = file_menu.add_action "Open"
save_action = file_menu.add_action "Save"
file_menu.add_separator
quit_action = file_menu.add_action "Quit"

# On "Quit", exit the application.
quit_action.on_triggered do
  Qt::Application.exit
end

# On "Open", ask the user to choose an image file to load.
open_action.on_triggered do
  # file_path = Qt::FileDialog.get_open_file_name
  file_url = Qt::FileDialog.get_open_file_url

  unless file_url.empty?
    draw_area.load file_url.to_local_file
  end
end

# On "Save", ask the user to choose a destination.
save_action.on_triggered do
  file_url = Qt::FileDialog.get_save_file_url

  unless file_url.empty?
    draw_area.save file_url.to_local_file
  end
end

# That's it: Open the window and start the Qt application!
window.show
Qt::Application.exec
