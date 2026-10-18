require "../spec_helper"

# The item views and text widgets of QtWidgets.

# Marks every "key" in a block bold, and remembers the blocks it saw.
private class KeywordHighlighter < Qt::SyntaxHighlighter
  getter blocks = [] of String
  getter weights = [] of Int32 # Of the first character of each block

  def highlight_block(text : String) : Void
    @blocks << text
    format = Qt::TextCharFormat.new
    format.font_weight = Qt::Font::Weight::Bold.to_i
    index = 0
    while found = text.index("key", index)
      set_format(found, 3, format)
      index = found + 3
    end
    @weights << format(0).font_weight unless text.empty?
    self.current_block_state = text.size
  end
end

# Appends to or removes from a list.
private class AppendCommand < Qt::UndoCommand
  def initialize(@list : Array(String), @value : String)
    super("append #{@value}")
  end

  def redo : Void
    @list << @value
  end

  def undo : Void
    @list.pop
  end
end

describe Qt::TreeWidget do
  it "holds items in columns" do
    tree = Qt::TreeWidget.new
    tree.column_count = 2
    tree.header_labels = ["Name", "Size"]
    root = Qt::TreeWidgetItem.new(tree, ["root", "1"])
    child = Qt::TreeWidgetItem.new(root, ["child", "2"])
    other = Qt::TreeWidgetItem.new(["other", "3"])
    tree.add_top_level_item(other)
    other.add_child(Qt::TreeWidgetItem.new(["grandchild", "4"]))

    tree.column_count.should eq(2)
    tree.top_level_item_count.should eq(2)
    tree.header_item.not_nil!.text(1).should eq("Size")
    tree.top_level_item(0).not_nil!.text(0).should eq("root")
    tree.top_level_item(2).should be_nil
    tree.index_of_top_level_item(other).should eq(1)
    root.child_count.should eq(1)
    root.child(0).not_nil!.text(1).should eq("2")
    root.child(1).should be_nil
    child.parent.not_nil!.to_unsafe.should eq(root.to_unsafe)
    other.parent.should be_nil
    child.tree_widget.should eq(tree)
    other.child(0).not_nil!.text(0).should eq("grandchild")

    child.set_text(1, "20")
    child.text(1).should eq("20")
    child.set_data(1, Qt::ItemDataRole::UserRole.to_i, Qt.variant(42))
    child.data(1, Qt::ItemDataRole::UserRole.to_i).to(Int32).should eq(42)
    child.expanded?.should be_false
    root.expanded = true
    root.expanded?.should be_true
    tree.current_item.should be_nil
    tree.current_item = child
    tree.current_item.not_nil!.text(0).should eq("child")
    tree.find_items("other", Qt::MatchFlags::MatchExactly).size.should eq(1)

    iterator = Qt::TreeWidgetItemIterator.new(tree)
    iterator.value.not_nil!.text(0).should eq("root")
    iterator.map(&.text(0)).to_a.should eq(["root", "child", "other", "grandchild"])
    iterator.value.should be_nil
    Qt::TreeWidgetItemIterator.new(other).map(&.text(0)).to_a.should eq(["other", "grandchild"])
    Qt::TreeWidgetItemIterator.new(tree, Qt::TreeWidgetItemIterator::IteratorFlags::NoChildren)
      .map(&.text(0)).to_a.should eq(["child", "grandchild"])

    tree.sort_items(0, Qt::SortOrder::DescendingOrder)
    tree.top_level_item(0).not_nil!.text(0).should eq("root")
    tree.sort_items(0, Qt::SortOrder::AscendingOrder)
    tree.top_level_item(0).not_nil!.text(0).should eq("other")
    taken = tree.take_top_level_item(0).not_nil!
    taken.text(0).should eq("other")
    tree.top_level_item_count.should eq(1)
    tree.take_top_level_item(5).should be_nil
    tree.clear
    tree.top_level_item_count.should eq(0)
  end

  it "shows a header view with sections" do
    tree = Qt::TreeWidget.new
    tree.header_labels = ["a", "b", "c"]
    header = tree.header.not_nil!
    header.count.should eq(3)
    header.orientation.should eq(Qt::Orientation::Horizontal)
    header.resize_section(1, 120)
    header.section_size(1).should eq(120)
    header.set_section_resize_mode(0, Qt::HeaderView::ResizeMode::Fixed)
    header.responds_to?(:cpp_initialize).should be_true # Qt's protected initialize()
    header.section_resize_mode(0).should eq(Qt::HeaderView::ResizeMode::Fixed)
    header.set_section_hidden(2, true)
    header.is_section_hidden(2).should be_true
    header.hidden_section_count.should eq(1)
    header.move_section(0, 1)
    header.visual_index(0).should eq(1)
    header.logical_index(0).should eq(1)
    header.stretch_last_section.should be_true
    header.stretch_last_section = false
    header.stretch_last_section.should be_false
  end
end

describe Qt::TreeView do
  it "views a model" do
    model = Qt::StandardItemModel.new
    parent = Qt::StandardItem.new("parent")
    parent.append_row(Qt::StandardItem.new("child"))
    model.append_row(parent)
    view = Qt::TreeView.new
    view.model = model
    view.model.should eq(model)
    view.is_expanded(parent.index).should be_false
    view.expand(parent.index)
    view.is_expanded(parent.index).should be_true
    view.collapse_all
    view.is_expanded(parent.index).should be_false
    view.indentation = 30
    view.indentation.should eq(30)
    view.header.not_nil!.count.should eq(1)
    view.index_above(parent.index).valid?.should be_false
  end
end

describe Qt::PlainTextEdit do
  it "edits plain text" do
    edit = Qt::PlainTextEdit.new("first")
    changes = 0
    edit.on_text_changed { changes += 1 }
    edit.append_plain_text("second")
    edit.to_plain_text.should eq("first\nsecond")
    edit.block_count.should eq(2)
    changes.should eq(1)
    edit.plain_text = "third"
    edit.to_plain_text.should eq("third")
    document = edit.document.not_nil!
    document.block_count.should eq(1)
    edit.line_wrap_mode = Qt::PlainTextEdit::LineWrapMode::NoWrap
    edit.line_wrap_mode.should eq(Qt::PlainTextEdit::LineWrapMode::NoWrap)
    edit.read_only = true
    edit.read_only?.should be_true
    layout = document.document_layout.not_nil!
    layout.document.should eq(document)
  end

  it "highlights blocks from Crystal" do
    document = Qt::TextDocument.new("a key\nno\nkeykey")
    highlighter = KeywordHighlighter.new(document)
    highlighter.document.should eq(document)
    highlighter.rehighlight
    highlighter.blocks.should eq(["a key", "no", "keykey"])
    highlighter.weights.should eq([Qt::Font::Weight::Normal.to_i, Qt::Font::Weight::Normal.to_i, Qt::Font::Weight::Bold.to_i])

    block = document.find_block_by_number(2)
    block.valid?.should be_true
    block.text.should eq("keykey")
    block.user_state.should eq(6)
    block.block_number.should eq(2)
    block.next.valid?.should be_false
    block.user_data.should be_nil
    document.first_block.text.should eq("a key")
    document.find_block(8).block_number.should eq(1)
  end
end

describe Qt::TextBrowser do
  it "shows a document" do
    browser = Qt::TextBrowser.new
    browser.html = "<h1>Title</h1><p>text</p>"
    browser.to_plain_text.should eq("Title\ntext")
    browser.read_only?.should be_true
    browser.open_links.should be_true
    browser.backward_available?.should be_false
    browser.search_paths = ["/tmp"]
    browser.search_paths.to_a.should eq(["/tmp"])
  end
end

describe Qt::UndoStack do
  it "undoes and redoes commands" do
    list = [] of String
    stack = Qt::UndoStack.new
    indexes = [] of Int32
    stack.on_index_changed { |index| indexes << index }
    stack.push(AppendCommand.new(list, "a"))
    stack.push(AppendCommand.new(list, "b"))
    list.should eq(["a", "b"])
    stack.count.should eq(2)
    stack.index.should eq(2)
    stack.can_undo.should be_true
    stack.can_redo.should be_false
    stack.undo_text.should eq("append b")
    stack.text(0).should eq("append a")
    stack.clean?.should be_false

    stack.undo
    list.should eq(["a"])
    stack.can_redo.should be_true
    stack.redo_text.should eq("append b")
    stack.redo
    list.should eq(["a", "b"])
    stack.index = 0
    list.should be_empty
    indexes.should eq([1, 2, 1, 2, 0])
    stack.set_clean
    stack.clean?.should be_true

    stack.begin_macro("both")
    stack.push(AppendCommand.new(list, "c"))
    stack.push(AppendCommand.new(list, "d"))
    stack.end_macro
    list.should eq(["c", "d"])
    stack.count.should eq(1)
    stack.command(0).not_nil!.child_count.should eq(2)
    stack.command(1).should be_nil
    stack.undo
    list.should be_empty

    group = Qt::UndoGroup.new
    group.active_stack.should be_nil
    group.add_stack(stack)
    group.active_stack = stack
    group.active_stack.should eq(stack)
    group.can_redo.should be_true
    group.redo
    list.should eq(["c", "d"])
    group.stacks.size.should eq(1)

    view = Qt::UndoView.new(stack)
    view.stack.should eq(stack)
    view.model.not_nil!.row_count.should eq(2) # The clean state and the macro
    view.empty_label = "nothing"
    view.empty_label.should eq("nothing")
  end
end

describe Qt::DataWidgetMapper do
  it "maps model columns to widgets" do
    model = Qt::StandardItemModel.new(2, 2)
    model.set_data(model.index(0, 0), Qt.variant("zero"))
    model.set_data(model.index(1, 0), Qt.variant("one"))
    edit = Qt::LineEdit.new
    mapper = Qt::DataWidgetMapper.new
    mapper.model.should be_nil
    mapper.model = model
    mapper.add_mapping(edit, 0)
    mapper.to_first
    edit.text.should eq("zero")
    mapper.to_next
    edit.text.should eq("one")
    mapper.current_index.should eq(1)
    mapper.mapped_section(edit).should eq(0)
    mapper.mapped_widget_at(0).should eq(edit)
    mapper.mapped_widget_at(1).should be_nil
    mapper.submit_policy.should eq(Qt::DataWidgetMapper::SubmitPolicy::AutoSubmit)
  end
end

describe Qt::ColumnView do
  it "views a model" do
    model = Qt::StandardItemModel.new
    root = Qt::StandardItem.new("root")
    root.append_row(Qt::StandardItem.new("child"))
    model.append_row(root)
    view = Qt::ColumnView.new
    view.model = model
    view.column_widths = [50, 60]
    view.column_widths.to_a.should eq([50]) # Only the root column is shown
    view.resize_grips_visible.should be_true
    view.resize_grips_visible = false
    view.resize_grips_visible.should be_false
    view.preview_widget.should be_nil
  end
end

describe Qt::ItemDelegate do
  it "is set on a view" do
    view = Qt::TableView.new
    delegate = Qt::ItemDelegate.new
    view.item_delegate = delegate
    view.item_delegate.should eq(delegate)
    delegate.has_clipping?.should be_true
    delegate.clipping = false
    delegate.has_clipping?.should be_false
  end
end
