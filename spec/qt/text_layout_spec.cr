require "../spec_helper"

# The text and font classes.

describe Qt::FontDatabase do
  it "lists families and describes fonts" do
    database = Qt::FontDatabase.new
    families = database.families.to_a
    families.should_not be_empty
    family = families.first
    database.has_family(family).should be_true
    database.has_family("no such family").should be_false
    database.styles(family).to_a.should_not be_empty
    Qt::FontDatabase.standard_sizes.to_a.should contain(12)
    Qt::FontDatabase.system_font(Qt::FontDatabase::SystemFont::GeneralFont).point_size.should be > 0
    database.writing_systems.to_a.should contain(Qt::FontDatabase::WritingSystem::Latin)

    family = "Helvetica" if families.includes?("Helvetica") # Has every glyph below
    font = Qt::Font.new(family, 12)
    info = Qt::FontInfo.new(font)
    info.family.should_not be_empty
    info.point_size.should be > 0
    info.bold.should be_false
    raw = Qt::RawFont.from_font(font)
    raw.valid?.should be_true
    raw.family_name.should_not be_empty
    raw.pixel_size.should be > 0
    indexes = raw.glyph_indexes_for_string("ab").to_a
    indexes.size.should eq(2)
    raw.advances_for_glyph_indexes(indexes).to_a.first.x.should be > 0
    raw.path_for_glyph(indexes.first).empty?.should be_false
  end

  it "measures text with float metrics" do
    font = Qt::Font.new("Helvetica", 12)
    metrics = Qt::FontMetricsF.new(font)
    metrics.height.should be > 0
    metrics.ascent.should be > metrics.descent
    width = metrics.horizontal_advance("Hello")
    width.should be > 0
    width.should be > metrics.horizontal_advance("He")
    metrics.horizontal_advance('W').should be > metrics.horizontal_advance('i')
    metrics.bounding_rect("Hello").width.should be > 0
    metrics.elided_text("Hello world, a long line", Qt::TextElideMode::Right, width).should end_with("…")
    metrics.size(0, "ab\ncd").height.should be >= metrics.height * 2
    Qt::FontMetricsF.new(Qt::FontMetrics.new(font)).height.should eq(metrics.height)
  end
end

describe Qt::TextLayout do
  it "lays out lines of a string" do
    font = Qt::Font.new("Helvetica", 12)
    layout = Qt::TextLayout.new("The quick brown fox jumps over the lazy dog", font)
    layout.text.should start_with("The quick")
    layout.cache_enabled = true
    layout.begin_layout
    y = 0.0
    while (line = layout.create_line).valid?
      line.line_width = 80.0
      line.position = Qt::PointF.new(0.0, y)
      y += line.height
    end
    layout.end_layout
    layout.line_count.should be > 2
    first = layout.line_at(0)
    first.line_number.should eq(0)
    first.text_start.should eq(0)
    first.text_length.should be > 0
    first.width.should eq(80.0)
    first.natural_text_width.should be <= 80.0
    first.rect.top.should eq(0.0)
    layout.line_at(1).y.should eq(first.height)
    layout.line_for_text_position(first.text_length + 1).line_number.should eq(1)
    layout.bounding_rect.height.should be_close(y, 0.01)
    layout.maximum_width.should be > layout.minimum_width
    layout.next_cursor_position(0).should eq(1)
    layout.next_cursor_position(0, Qt::TextLayout::CursorMode::SkipWords).should eq(4)
    first.cursor_to_x(2).should be > 0.0
    first.x_to_cursor(0.0).should eq(0)
    runs = layout.glyph_runs
    runs.to_a.should_not be_empty
    runs.to_a.first.glyph_indexes.size.should be > 0

    image = Qt::Image.new(100, 60, Qt::Image::Format::Argb32)
    image.fill(Qt::Color.new(255, 255, 255))
    painter = Qt::Painter.new(image)
    painter.pen = Qt::Color.new(0, 0, 0)
    layout.draw(painter, Qt::PointF.new(0.0, 0.0))
    painter.end
    painted = (0...100).any? { |x| (0...60).any? { |yy| image.pixel_color(x, yy).name != "#ffffff" } }
    painted.should be_true

    range = Qt::TextLayoutFormatRange.new
    range.start = 0
    range.length = 3
    format = Qt::TextCharFormat.new
    format.font_weight = Qt::Font::Weight::Bold.to_i
    range.format = format
    layout.formats = [range] # Invalidates the layout
    layout.formats.to_a.size.should eq(1)
    layout.formats.to_a.first.length.should eq(3)
  end

  it "sizes static text" do
    text = Qt::StaticText.new("Static text")
    text.text.should eq("Static text")
    text.text_format = Qt::TextFormatEnum::PlainText
    text.performance_hint = Qt::StaticText::PerformanceHint::AggressiveCaching
    text.prepare(Qt::Transform.new, Qt::Font.new("Helvetica", 12))
    text.size.width.should be > 0
    text.size.height.should be > 0
    text.text_width = 20.0 # Wraps between the words
    text.text_width.should eq(20.0)
    text.size.height.should be > Qt::FontMetricsF.new(Qt::Font.new("Helvetica", 12)).height
  end

  it "finds text boundaries" do
    finder = Qt::TextBoundaryFinder.new(Qt::TextBoundaryFinder::BoundaryType::Word, "one two")
    finder.valid?.should be_true
    finder.type.should eq(Qt::TextBoundaryFinder::BoundaryType::Word)
    finder.position.should eq(0)
    finder.at_boundary?.should be_true
    finder.boundary_reasons.includes?(Qt::TextBoundaryFinder::BoundaryReasons::StartOfItem).should be_true
    finder.to_next_boundary.should eq(3)
    finder.boundary_reasons.includes?(Qt::TextBoundaryFinder::BoundaryReasons::EndOfItem).should be_true
    finder.to_next_boundary.should eq(4)
    finder.to_end
    finder.position.should eq(7)
    finder.to_next_boundary.should eq(-1)
    finder.position = 2
    finder.at_boundary?.should be_false
  end
end

describe Qt::TextDocument do
  it "holds tables and lists" do
    document = Qt::TextDocument.new
    cursor = Qt::TextCursor.new(document)
    cursor.insert_text("Intro")
    cursor.insert_block
    format = Qt::TextTableFormat.new
    format.cell_padding = 2.0
    format.border = 1.0
    table = cursor.insert_table(2, 3, format).not_nil!
    table.rows.should eq(2)
    table.columns.should eq(3)
    table.format.cell_padding.should eq(2.0)
    cell = table.cell_at(1, 2)
    cell.valid?.should be_true
    cell.row.should eq(1)
    cell.column.should eq(2)
    cell.first_cursor_position.insert_text("last")
    table.cell_at(0, 0).first_cursor_position.insert_text("first")
    table.cell_at(cursor).row.should eq(0)
    table.append_rows(1)
    table.rows.should eq(3)
    table.merge_cells(0, 0, 1, 2)
    table.cell_at(0, 1).column_span.should eq(2)
    cursor.current_table.not_nil!.to_unsafe.should eq(table.to_unsafe)
    cursor.current_frame.not_nil!.to_unsafe.should eq(table.to_unsafe)
    table.first_position.should be > 0
    table.last_position.should be > table.first_position
    table.parent_frame.not_nil!.to_unsafe.should eq(document.root_frame.not_nil!.to_unsafe)
    cell_format = Qt::TextTableCellFormat.new
    cell_format.left_padding = 3.0
    cell_format.padding = 4.0
    cell_format.top_padding.should eq(4.0)
    cell.format = cell_format
    table.cell_at(1, 2).format.to_table_cell_format.top_padding.should eq(4.0)

    cursor.move_position(Qt::TextCursor::MoveOperation::End)
    cursor.insert_block
    list = cursor.insert_list(Qt::TextListFormat::Style::ListDecimal).not_nil!
    cursor.insert_text("one")
    cursor.insert_block
    cursor.insert_text("two")
    list.count.should eq(2)
    list.item(1).text.should eq("two")
    list.item_text(list.item(1)).should eq("2.")
    list.item_number(cursor.block).should eq(1)
    list.format.style.should eq(Qt::TextListFormat::Style::ListDecimal)
    cursor.current_list.not_nil!.to_unsafe.should eq(list.to_unsafe)
    cursor.block.text_list.not_nil!.to_unsafe.should eq(list.to_unsafe)
    list.document.not_nil!.to_unsafe.should eq(document.to_unsafe)
    list.remove_item(0)
    list.count.should eq(1)

    document.to_plain_text.should contain("first")
    document.to_plain_text.should contain("two")
  end

  it "iterates frames, blocks and fragments" do
    document = Qt::TextDocument.new
    cursor = Qt::TextCursor.new(document)
    cursor.insert_text("plain ")
    bold = Qt::TextCharFormat.new
    bold.font_weight = Qt::Font::Weight::Bold.to_i
    cursor.insert_text("bold", bold)
    cursor.insert_block
    frame_format = Qt::TextFrameFormat.new
    frame_format.border = 2.0
    frame = cursor.insert_frame(frame_format).not_nil!
    cursor.insert_text("inside")
    frame.frame_format.border.should eq(2.0)
    root = document.root_frame.not_nil!
    frame.parent_frame.not_nil!.to_unsafe.should eq(root.to_unsafe)
    root.child_frames.to_a.size.should eq(1)

    block = document.first_block
    fragments = block.begin.to_a
    fragments.size.should eq(2)
    fragments.map(&.text).should eq(["plain ", "bold"])
    fragments[1].char_format.font_weight.should eq(Qt::Font::Weight::Bold.to_i)
    fragments[1].position.should eq(6)
    fragments[1].length.should eq(4)
    fragments[1].contains(7).should be_true
    block.text_formats.to_a.size.should eq(2)
    block.text_formats.to_a[1].start.should eq(6)

    items = root.begin.to_a
    items.size.should be >= 3 # The blocks around the frame, and the frame
    items.first.should be_a(Qt::TextBlock)
    items.first.as(Qt::TextBlock).text.should eq("plain bold")
    frames = items.select(Qt::TextFrame)
    frames.size.should eq(1)
    frames.first.to_unsafe.should eq(frame.to_unsafe)
    frame.begin.to_a.size.should eq(1)
    frame.begin.to_a.first.as(Qt::TextBlock).text.should eq("inside")
    iterator = frame.begin
    iterator.at_end.should be_false
    iterator.succ!
    iterator.at_end.should be_true

    document.document_layout.not_nil!.document_size.width.should be > 0
    context = Qt::TextDocumentLayoutPaintContext.new
    context.cursor_position.should eq(-1)
    context.clip = Qt::RectF.new(0.0, 0.0, 10.0, 10.0)
    context.clip.width.should eq(10.0)
    selection = Qt::TextDocumentLayoutSelection.new
    selection.cursor = cursor
    selection.format = bold
    context.selections = [selection]
    context.selections.to_a.size.should eq(1)
    context.selections.to_a.first.format.font_weight.should eq(Qt::Font::Weight::Bold.to_i)
  end

  it "converts fragments to and from HTML" do
    fragment = Qt::TextDocumentFragment.from_html("<p>Hello <b>world</b></p>")
    fragment.empty?.should be_false
    fragment.to_plain_text.should eq("Hello world")
    fragment.to_html.should contain("world")
    Qt::TextDocumentFragment.from_plain_text("a\nb").to_plain_text.should eq("a\nb")

    document = Qt::TextDocument.new
    cursor = Qt::TextCursor.new(document)
    cursor.insert_fragment(fragment)
    document.to_plain_text.should eq("Hello world")
    document.to_markdown.should contain("**world**") # Qt 5's fragments have no markdown methods
    cursor.select(Qt::TextCursor::SelectionType::WordUnderCursor)
    Qt::TextDocumentFragment.new(cursor).to_plain_text.should eq("world")
    Qt::TextDocumentFragment.new(document).to_plain_text.should eq("Hello world")

    image_format = Qt::TextImageFormat.new
    image_format.name = "image.png"
    image_format.width = 8.0
    image_format.name.should eq("image.png")
    image_format.width.should eq(8.0)
    image_format.valid?.should be_true
    cursor.move_position(Qt::TextCursor::MoveOperation::End)
    cursor.insert_image(image_format)
    cursor.char_format.image_format?.should be_true

    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    writer = Qt::TextDocumentWriter.new(buffer, "plaintext".to_slice)
    writer.format.should eq("plaintext".to_slice)
    writer.write(document).should be_true
    String.new(buffer.data).should start_with("Hello world")
    Qt::TextDocumentWriter.supported_document_formats.map { |f| String.new(f) }.should contain("HTML")
  end
end
