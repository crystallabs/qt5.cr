require "../spec_helper"

describe "config/methods.yml" do
  it "names raise raise_" do
    widget = Qt::Widget.new
    widget.raise_
    widget.responds_to?(:raise_).should be_true
  end

  it "makes results Qt never returns null non-nilable" do
    window = Qt::MainWindow.new
    typeof(window.menu_bar).should eq(Qt::MenuBar)
    typeof(window.status_bar).should eq(Qt::StatusBar)
    menu = window.menu_bar.add_menu("File")
    typeof(menu).should eq(Qt::Menu)
    menu.title.should eq("File")
    typeof(menu.add_separator).should eq(Qt::Action)
    typeof(Qt::TreeWidget.new.header_item).should eq(Qt::TreeWidgetItem)
    typeof(Qt::TextEdit.new.document).should eq(Qt::TextDocument)
    typeof(window.window).should eq(Qt::Widget)
    window.parent_widget.should be_nil # Still nilable
  end

  it "lets nil into pointer arguments Qt accepts null for" do
    edit = Qt::LineEdit.new
    edit.validator = Qt::IntValidator.new(0, 9)
    edit.validator.should_not be_nil
    edit.validator = nil
    edit.validator.should be_nil

    view = Qt::ListView.new
    view.model = Qt::StringListModel.new
    view.model.should_not be_nil
    view.model = nil
    view.model.should be_nil
  end
end
