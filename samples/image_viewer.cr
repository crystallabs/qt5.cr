require "../src/qt5"

# Create the application first
qApp = Qt::Application.new

# Build the main window:
window = Qt::MainWindow.new
window.window_title = "Crystal/Qt Imageviewer example"

# We'll use a Label as display.  By default, let it tell the user to open an
# image.
image_label = Qt::Label.new "Select an image!"

# The scroll area is our central widget:  We put the image label into it, so the
# user can scroll around.
scroll_area = Qt::ScrollArea.new
scroll_area.widget = image_label    # Just stuff the label into the scroll area
scroll_area.widget_resizable = true # And tell it to resize our label for us
window.central_widget = scroll_area

# Now, we add a File menu, with "Open" and "Quit" options
file_menu = window.menu_bar.add_menu "File"
open_action = file_menu.add_action "Open"
quit_action = file_menu.add_action "Quit"

# Also, add shortcuts - These are window-wide by default!
open_action.shortcut = Qt::KeySequence.from_string("Ctrl+O")
quit_action.shortcut = Qt::KeySequence.from_string("Ctrl+Q")

# Clicking on "Quit" (or hitting Ctrl+Q) will exit the program
quit_action.on_triggered do
  Qt::Application.exit
end

# Clicking on "Open" ...
open_action.on_triggered do
  # Show a "Open file..." dialog
  file_url = Qt::FileDialog.get_open_file_url

  unless file_url.empty? # Did the user choose something?
    pixmap = Qt::Pixmap.new
    if pixmap.load file_url.to_local_file # Try to load it
      image_label.pixmap = pixmap         # And on success, display it.
    end
  end
end

# Now, simply show our window, start the application, and we're done.
window.show
Qt::Application.exec
