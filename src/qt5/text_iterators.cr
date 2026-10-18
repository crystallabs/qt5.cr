module Qt
  # Iterates the child frames and blocks of a `TextFrame` (or a
  # `TextTableCell`), see `TextFrame#begin`.
  #
  # ```
  # document.root_frame.begin.each { |child| ... } # TextFrame or TextBlock
  # ```
  class TextFrameIterator
    include Iterator(TextFrame | TextBlock)

    # Returns the current frame or block, or `nil` past the last one.
    def value : TextFrame | TextBlock | Nil
      return nil if at_end
      current_frame || current_block
    end

    # Returns the current frame or block and advances, see `Iterator#next`.
    def next : TextFrame | TextBlock | Iterator::Stop
      if item = value
        succ!
        item
      else
        stop
      end
    end
  end

  # Iterates the fragments of a `TextBlock`, see `TextBlock#begin`.
  #
  # ```
  # block.begin.each { |fragment| puts fragment.text }
  # ```
  class TextBlockIterator
    include Iterator(TextFragment)

    # Returns the current fragment, or `nil` past the last one.
    def value : TextFragment?
      fragment unless at_end
    end

    # Returns the current fragment and advances, see `Iterator#next`.
    def next : TextFragment | Iterator::Stop
      if item = value
        succ!
        item
      else
        stop
      end
    end
  end
end
