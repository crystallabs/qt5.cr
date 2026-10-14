module Qt
  # A painter lets you draw on a `Qt::PaintDevice`.  Among these are
  # `Qt::Widget`s (But only during `Qt::Widget#paint_event`), `Qt::Image`
  # and `Qt::Pixmap`.
  #
  # Use `Painter.draw` to easily open and close a painter.
  class Painter
    # Creates a temporary drawer for *target*, yields it, and closes it again
    # after the block has returned.
    def self.draw(target, &)
      draw(target.as_paint_device) do |painter|
        yield painter
      end
    end

    # :ditto:
    def self.draw(target : Qt::PaintDevice, &)
      painter = new(target)
      yield painter
    ensure
      painter.try(&.end)
    end

    # Saves the current drawing context (rotation, scaling, etc.), yields, and
    # restores the drawing context afterwards to what it was before.
    def restore_after(&)
      save
      yield
    ensure
      restore
    end
  end
end
