require "../spec_helper"

# An icon engine written in Crystal paints the icon; `clone` returns a fresh
# engine, as the QIcon copies take one each.  The abstract def is
# `IconEngine?` (a pointer result); an override returning nil passes a null
# pointer to C++.
private class SquareIconEngine < Qt::IconEngine
  def paint(painter : Qt::Painter, rect : Qt::Rect, mode : Qt::Icon::Mode, state : Qt::Icon::State) : Void
    painter.fill_rect(rect, Qt::Color.new(0, 128, 0))
  end

  def clone : Qt::IconEngine?
    SquareIconEngine.new
  end

  def key : String
    "square"
  end
end

# An editor creator makes the editor widget for a type and names the property
# holding its value.  QItemEditorCreatorBase is abstract and declares no
# constructor; its implicit default one is wrapped.
private class SpinBoxCreator < Qt::ItemEditorCreatorBase
  def create_widget(parent : Qt::Widget) : Qt::Widget?
    Qt::SpinBox.new(parent)
  end

  def value_property_name : Bytes
    "value".to_slice
  end
end

private def table(rows : Int32, columns : Int32, prefix : String) : Qt::StandardItemModel
  model = Qt::StandardItemModel.new(rows, columns)
  rows.times do |row|
    columns.times do |column|
      model.set_item(row, column, Qt::StandardItem.new("#{prefix}#{row}#{column}"))
    end
  end
  model
end

describe Qt::ConcatenateTablesProxyModel do
  it "stacks the rows of several models" do
    first = table(2, 2, "a")
    second = table(1, 2, "b")
    proxy = Qt::ConcatenateTablesProxyModel.new
    proxy.add_source_model(first)
    proxy.add_source_model(second)
    proxy.source_models.size.should eq(2)
    proxy.row_count.should eq(3)
    proxy.column_count.should eq(2)
    proxy.data(proxy.index(2, 1)).to(String).should eq("b01")
    proxy.map_to_source(proxy.index(2, 0)).row.should eq(0)
    proxy.map_from_source(second.index(0, 1)).row.should eq(2)
    proxy.remove_source_model(first)
    proxy.row_count.should eq(1)
  end
end

describe Qt::TransposeProxyModel do
  it "swaps rows and columns" do
    source = table(2, 3, "s")
    proxy = Qt::TransposeProxyModel.new
    proxy.source_model = source
    proxy.row_count.should eq(3)
    proxy.column_count.should eq(2)
    proxy.data(proxy.index(2, 1)).to(String).should eq("s12")
    proxy.map_to_source(proxy.index(2, 1)).column.should eq(2)
    proxy.set_data(proxy.index(0, 0), Qt.variant("changed")).should be_true
    source.item(0, 0).not_nil!.text.should eq("changed")
  end
end

describe Qt::FileIconProvider do
  it "provides icons and types" do
    provider = Qt::FileIconProvider.new
    provider.icon(Qt::FileIconProvider::IconType::Folder).null?.should be_false
    info = Qt::FileInfo.new(Dir.tempdir)
    provider.icon(info).null?.should be_false
    provider.type(info).should_not be_empty
    provider.options = Qt::FileIconProvider::Options::DontUseCustomDirectoryIcons
    provider.options.should eq(Qt::FileIconProvider::Options::DontUseCustomDirectoryIcons)

    model = Qt::FileSystemModel.new
    model.icon_provider = provider
    model.icon_provider.not_nil!.to_unsafe.should eq(provider.to_unsafe)
  end
end

describe Qt::ItemEditorFactory do
  it "creates editors from Crystal creators" do
    factory = Qt::ItemEditorFactory.new
    creator = SpinBoxCreator.new
    factory.register_editor(Qt::MetaType::Type::Int.to_i, creator)
    parent = Qt::Widget.new
    editor = factory.create_editor(Qt::MetaType::Type::Int.to_i, parent).not_nil!
    editor.to?(Qt::SpinBox).should_not be_nil
    String.new(factory.value_property_name(Qt::MetaType::Type::Int.to_i)).should eq("value")
    Qt::ItemEditorFactory.default_factory.not_nil!.create_editor(Qt::MetaType::Type::QString.to_i, parent).not_nil!.to?(Qt::LineEdit).should_not be_nil
  end
end

describe Qt::IconEngine do
  it "paints an icon from Crystal" do
    icon = Qt::Icon.new(SquareIconEngine.new)
    icon.null?.should be_false
    pixmap = icon.pixmap(Qt::Size.new(4, 4))
    pixmap.null?.should be_false
    pixmap.to_image.pixel_color(1, 1).name.should eq("#008000")

    image = Qt::Image.new(8, 8, Qt::Image::Format::Argb32)
    image.fill(Qt::Color.new(255, 255, 255))
    painter = Qt::Painter.new(image)
    icon.paint(painter, Qt::Rect.new(0, 0, 4, 4))
    painter.end
    image.pixel_color(1, 1).name.should eq("#008000")
    image.pixel_color(6, 6).name.should eq("#ffffff")
    icon.name.should eq("") # The engine doesn't name it
  end
end

describe Qt::IconEngineScaledPixmapArgument do
  it "holds virtual_hook's arguments" do
    argument = Qt::IconEngineScaledPixmapArgument.new
    argument.size = Qt::Size.new(4, 4)
    argument.scale = 2.0
    argument.mode = Qt::Icon::Mode::Disabled
    argument.size.should eq(Qt::Size.new(4, 4))
    argument.scale.should eq(2.0)
    argument.mode.should eq(Qt::Icon::Mode::Disabled)
    argument.pixmap.null?.should be_true
  end
end

describe Qt::StyleOptionTabV4 do
  it "holds the version 4 field" do
    option = Qt::StyleOptionTabV4.new
    option.tab_index = 3
    option.tab_index.should eq(3)
    option.text = "tab"
    option.text.should eq("tab")
  end
end

describe Qt::StyleHintReturnMask do
  it "returns a region or a variant" do
    mask = Qt::StyleHintReturnMask.new
    mask.type.should eq(Qt::StyleHintReturn::HintReturnType::Mask.to_i)
    mask.region = Qt::Region.new(0, 0, 4, 4)
    mask.region.bounding_rect.should eq(Qt::Rect.new(0, 0, 4, 4))
    variant = Qt::StyleHintReturnVariant.new
    variant.type.should eq(Qt::StyleHintReturn::HintReturnType::Variant.to_i)
    variant.variant = Qt.variant(7)
    variant.variant.to(Int32).should eq(7)
  end
end

describe Qt::WidgetItemV2 do
  it "wraps a widget" do
    parent = Qt::Widget.new
    widget = Qt::PushButton.new("ok", parent)
    item = Qt::WidgetItemV2.new(widget)
    item.widget.not_nil!.to_unsafe.should eq(widget.to_unsafe)
    item.empty?.should be_false
    item.size_hint.width.should be > 0
    item.has_height_for_width?.should be_false
    widget.hide
    item.empty?.should be_true # An empty item has no size hint
    item.size_hint.width.should eq(0)
  end
end

describe Qt::StackedWidget do
  it "shows one page at a time" do
    stack = Qt::StackedWidget.new
    first = Qt::Label.new("first")
    second = Qt::Label.new("second")
    stack.add_widget(first).should eq(0)
    stack.insert_widget(1, second).should eq(1)
    stack.count.should eq(2)
    stack.current_index.should eq(0)
    changed = -1
    stack.on_current_changed { |index| changed = index }
    stack.current_widget = second
    stack.current_index.should eq(1)
    changed.should eq(1)
    stack.widget(0).not_nil!.to?(Qt::Label).not_nil!.text.should eq("first")
    stack.index_of(second).should eq(1)
    stack.remove_widget(first)
    stack.count.should eq(1)
    stack.widget(5).should be_nil
  end
end
