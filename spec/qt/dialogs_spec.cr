require "../spec_helper"

# The dialogs and windows of QtWidgets.  None of these calls exec().

# A wizard page which is complete once its line edit has text.
private class NamePage < Qt::WizardPage
  getter edit = Qt::LineEdit.new

  def initialize
    super()
    self.title = "Name"
    register_field("name*", @edit)
  end

  def next_id : Int32
    7
  end
end

describe Qt::ColorDialog do
  it "holds a color" do
    dialog = Qt::ColorDialog.new(Qt::Color.new(10, 20, 30))
    dialog.current_color.should eq(Qt::Color.new(10, 20, 30))
    changed = [] of Qt::Color
    dialog.on_current_color_changed { |color| changed << color }
    dialog.current_color = Qt::Color.new(255, 0, 0)
    dialog.current_color.red.should eq(255)
    changed.size.should eq(1)
    dialog.set_option(Qt::ColorDialog::Option::ShowAlphaChannel)
    dialog.test_option(Qt::ColorDialog::Option::ShowAlphaChannel).should be_true
    dialog.options.should eq(Qt::ColorDialog::Options::ShowAlphaChannel)
    Qt::ColorDialog.custom_count.should be > 0
  end
end

describe Qt::FontDialog do
  it "holds a font" do
    font = Qt::Font.new("Helvetica", 14)
    dialog = Qt::FontDialog.new(font)
    dialog.current_font.point_size.should eq(14)
    dialog.set_option(Qt::FontDialog::Option::MonospacedFonts)
    dialog.test_option(Qt::FontDialog::Option::MonospacedFonts).should be_true
  end
end

describe Qt::InputDialog do
  it "holds text, int and double values" do
    dialog = Qt::InputDialog.new
    dialog.label_text = "Name?"
    dialog.label_text.should eq("Name?")
    dialog.text_value = "me"
    dialog.text_value.should eq("me")
    dialog.input_mode.should eq(Qt::InputDialog::InputMode::TextInput)
    dialog.input_mode = Qt::InputDialog::InputMode::IntInput
    dialog.set_int_range(0, 10)
    dialog.int_value = 7
    dialog.int_value.should eq(7)
    dialog.int_maximum.should eq(10)
    dialog.input_mode = Qt::InputDialog::InputMode::DoubleInput
    dialog.double_decimals = 1
    dialog.double_value = 2.5
    dialog.double_value.should eq(2.5)
    dialog.combo_box_items = ["a", "b"]
    dialog.combo_box_items.to_a.should eq(["a", "b"])
    dialog.ok_button_text = "Go"
    dialog.ok_button_text.should eq("Go")
  end
end

describe Qt::ProgressDialog do
  it "tracks progress" do
    dialog = Qt::ProgressDialog.new("Working", "Stop", 0, 10)
    dialog.label_text.should eq("Working")
    dialog.maximum.should eq(10)
    dialog.value = 4
    dialog.value.should eq(4)
    dialog.was_canceled.should be_false
    dialog.auto_close.should be_true
    dialog.cancel
    dialog.was_canceled.should be_true
  end
end

describe Qt::ErrorMessage do
  it "is a dialog" do
    dialog = Qt::ErrorMessage.new
    dialog.modal?.should be_false # Qt 6 makes it modal by default
    dialog.modal = true
    dialog.modal?.should be_true
    dialog.window_title = "Error"
    dialog.window_title.should eq("Error")
  end
end

describe Qt::Wizard do
  it "holds pages" do
    wizard = Qt::Wizard.new
    first = NamePage.new
    last = Qt::WizardPage.new
    last.title = "Last"
    last.final_page = true
    wizard.add_page(first).should eq(0)
    wizard.set_page(7, last)
    wizard.page_ids.to_a.should eq([0, 7])
    wizard.page(7).not_nil!.title.should eq("Last")
    wizard.page(8).should be_nil
    wizard.start_id.should eq(0)
    wizard.current_id.should eq(-1) # Not shown yet
    wizard.current_page.should be_nil
    wizard.restart
    wizard.current_id.should eq(0)
    wizard.current_page.should eq(first)
    wizard.next_id.should eq(7)     # From the Crystal override
    first.complete?.should be_false # The mandatory field is empty
    first.edit.text = "Someone"
    first.complete?.should be_true
    wizard.field("name").to(String).should eq("Someone")
    wizard.next
    wizard.current_id.should eq(7)
    wizard.visited_ids.to_a.should eq([0, 7])
    wizard.has_visited_page(7).should be_true
    wizard.back
    wizard.current_id.should eq(0)
    wizard.wizard_style = Qt::Wizard::Style::ModernStyle
    wizard.wizard_style.should eq(Qt::Wizard::Style::ModernStyle)
    wizard.set_option(Qt::Wizard::Option::NoBackButtonOnStartPage)
    wizard.test_option(Qt::Wizard::Option::NoBackButtonOnStartPage).should be_true
    wizard.set_button_text(Qt::Wizard::Button::NextButton, "Onwards")
    wizard.button_text(Qt::Wizard::Button::NextButton).should eq("Onwards")
    wizard.button_layout = [Qt::Wizard::Button::Stretch, Qt::Wizard::Button::NextButton]
    wizard.remove_page(7)
    wizard.page_ids.to_a.should eq([0])
  end
end

describe Qt::DialogButtonBox do
  it "holds standard buttons" do
    box = Qt::DialogButtonBox.new(Qt::DialogButtonBox::StandardButtons::Ok | Qt::DialogButtonBox::StandardButtons::Cancel)
    box.standard_buttons.should eq(Qt::DialogButtonBox::StandardButtons::Ok | Qt::DialogButtonBox::StandardButtons::Cancel)
    box.buttons.size.should eq(2)
    box.button(Qt::DialogButtonBox::StandardButton::Save).should be_nil
    ok = box.button(Qt::DialogButtonBox::StandardButton::Ok).not_nil!
    box.standard_button(ok).should eq(Qt::DialogButtonBox::StandardButton::Ok)
    box.button_role(ok).should eq(Qt::DialogButtonBox::ButtonRole::AcceptRole)
    custom = box.add_button("Maybe", Qt::DialogButtonBox::ButtonRole::ActionRole).not_nil!
    custom.text.should eq("Maybe")
    box.buttons.size.should eq(3)
    accepted = 0
    clicked = [] of String
    box.on_accepted { accepted += 1 }
    box.on_clicked { |button| clicked << button.text }
    ok.click
    accepted.should eq(1)
    clicked.should eq([ok.text])
    box.remove_button(custom)
    box.buttons.size.should eq(2)
    box.orientation = Qt::Orientation::Vertical
    box.orientation.should eq(Qt::Orientation::Vertical)
  end
end

describe Qt::MdiArea do
  it "holds sub windows" do
    area = Qt::MdiArea.new
    first = area.add_sub_window(Qt::Label.new("one")).not_nil!
    second = Qt::MdiSubWindow.new
    second.widget.should be_nil
    second.widget = Qt::Label.new("two")
    second.window_title = "second"
    area.add_sub_window(second)
    area.sub_window_list.size.should eq(2)
    area.sub_window_list.map(&.window_title).to_a.should eq(["", "second"])
    first.widget.should_not be_nil
    second.widget.should_not be_nil
    area.active_sub_window = second
    area.view_mode = Qt::MdiArea::ViewMode::TabbedView
    area.view_mode.should eq(Qt::MdiArea::ViewMode::TabbedView)
    area.remove_sub_window(first)
    area.sub_window_list.size.should eq(1)
    second.set_option(Qt::MdiSubWindow::Option::RubberBandResize)
    second.test_option(Qt::MdiSubWindow::Option::RubberBandResize).should be_true
    second.keyboard_single_step.should eq(5)
  end
end

describe Qt::ToolBox do
  it "holds items" do
    box = Qt::ToolBox.new
    box.add_item(Qt::Label.new("a"), "First").should eq(0)
    box.add_item(Qt::Label.new("b"), "Second").should eq(1)
    box.count.should eq(2)
    box.item_text(1).should eq("Second")
    box.set_item_text(1, "Other")
    box.item_text(1).should eq("Other")
    changes = [] of Int32
    box.on_current_changed { |index| changes << index }
    box.current_index = 1
    box.current_index.should eq(1)
    changes.should eq([1])
    box.index_of(box.current_widget.not_nil!).should eq(1)
    box.widget(5).should be_nil
    box.remove_item(0)
    box.count.should eq(1)
  end
end

describe Qt::SplashScreen do
  it "shows a message" do
    splash = Qt::SplashScreen.new(Qt::Pixmap.new(20, 10))
    splash.show_message("Loading", Qt::Alignment::AlignCenter.to_i)
    splash.message.should eq("Loading")
    splash.pixmap.width.should eq(20)
    splash.clear_message
    splash.message.should eq("")
  end
end

describe Qt::Splitter do
  it "splits widgets with handles" do
    splitter = Qt::Splitter.new(Qt::Orientation::Horizontal)
    splitter.add_widget(Qt::Label.new("left"))
    splitter.add_widget(Qt::Label.new("right"))
    splitter.count.should eq(2)
    splitter.resize(300, 100)
    splitter.sizes = [100, 200]
    splitter.sizes.to_a.sum.should be > 0
    handle = splitter.handle(1).not_nil!
    handle.should be_a(Qt::SplitterHandle)
    handle.orientation.should eq(Qt::Orientation::Horizontal)
    handle.splitter.should eq(splitter)
    splitter.handle(2).should be_nil
    splitter.children_collapsible = false
    splitter.children_collapsible.should be_false
  end
end

describe Qt::SizeGrip do
  it "is a widget" do
    parent = Qt::Widget.new
    grip = Qt::SizeGrip.new(parent)
    grip.parent_widget.should eq(parent)
    grip.size_hint.width.should be > 0
  end
end

describe Qt::RubberBand do
  it "has a shape" do
    band = Qt::RubberBand.new(Qt::RubberBand::Shape::Rectangle)
    band.shape.should eq(Qt::RubberBand::Shape::Rectangle)
    band.set_geometry(1, 2, 30, 40)
    band.width.should eq(30)
  end
end

describe Qt::FocusFrame do
  it "frames a widget" do
    parent = Qt::Widget.new
    edit = Qt::LineEdit.new(parent) # Only a widget in a window is framed
    frame = Qt::FocusFrame.new
    frame.widget.should be_nil
    frame.widget = edit
    frame.widget.should eq(edit)
  end
end

describe Qt::KeySequenceEdit do
  it "holds a key sequence" do
    sequence = Qt::KeySequence.new("Ctrl+S")
    edit = Qt::KeySequenceEdit.new(sequence)
    edit.key_sequence.to_string.should eq("Ctrl+S")
    changes = [] of String
    edit.on_key_sequence_changed { |seq| changes << seq.to_string }
    edit.key_sequence = Qt::KeySequence.new("Ctrl+Q")
    changes.should eq(["Ctrl+Q"])
    edit.clear
    edit.key_sequence.empty?.should be_true
  end
end

describe Qt::FontComboBox do
  it "lists fonts" do
    combo = Qt::FontComboBox.new
    combo.count.should be > 0
    combo.current_font = Qt::Font.new("Helvetica")
    combo.current_font.family.should eq("Helvetica")
    combo.font_filters = Qt::FontComboBox::FontFilters::MonospacedFonts
    combo.font_filters.should eq(Qt::FontComboBox::FontFilters::MonospacedFonts)
    combo.current_font.family.should_not eq("Helvetica") # Filtered out
    combo.writing_system.should eq(Qt::FontDatabase::WritingSystem::Any)
  end
end

describe Qt::DateEdit do
  it "edits dates and times" do
    date_edit = Qt::DateEdit.new(Qt::Date.new(2026, 10, 18))
    date_edit.date.year.should eq(2026)
    date_edit.date.day.should eq(18)
    date_edit.date = Qt::Date.new(2027, 1, 2)
    date_edit.date.month.should eq(1)
    date_edit.display_format = "yyyy-MM-dd"
    date_edit.text.should eq("2027-01-02")
    date_edit.minimum_date = Qt::Date.new(2000, 1, 1)
    date_edit.minimum_date.year.should eq(2000)

    time_edit = Qt::TimeEdit.new(Qt::Time.new(13, 45))
    time_edit.time.hour.should eq(13)
    time_edit.time.minute.should eq(45)
    time_edit.display_format = "HH:mm"
    time_edit.time = Qt::Time.new(7, 5)
    time_edit.text.should eq("07:05")
  end
end

describe Qt::CalendarWidget do
  it "selects dates" do
    calendar = Qt::CalendarWidget.new
    calendar.selected_date = Qt::Date.new(2026, 10, 18)
    calendar.selected_date.should eq(Qt::Date.new(2026, 10, 18))
    calendar.year_shown.should eq(2026)
    calendar.month_shown.should eq(10)
    calendar.show_next_month
    calendar.month_shown.should eq(11)
    calendar.set_date_range(Qt::Date.new(2026, 1, 1), Qt::Date.new(2026, 12, 31))
    calendar.maximum_date.month.should eq(12)
    calendar.first_day_of_week = Qt::DayOfWeek::Monday
    calendar.first_day_of_week.should eq(Qt::DayOfWeek::Monday)
    calendar.selection_mode = Qt::CalendarWidget::SelectionMode::NoSelection
    calendar.selection_mode.should eq(Qt::CalendarWidget::SelectionMode::NoSelection)
    calendar.grid_visible = true
    calendar.grid_visible?.should be_true
    format = Qt::TextCharFormat.new
    format.font_weight = Qt::Font::Weight::Bold.to_i
    calendar.set_date_text_format(Qt::Date.new(2026, 10, 18), format)
    calendar.date_text_format(Qt::Date.new(2026, 10, 18)).font_weight.should eq(Qt::Font::Weight::Bold.to_i)
  end
end

describe Qt::CommandLinkButton do
  it "has a description" do
    button = Qt::CommandLinkButton.new("Go", "Does it")
    button.text.should eq("Go")
    button.description.should eq("Does it")
    button.description = "Other"
    button.description.should eq("Other")
  end
end

describe Qt::Shortcut do
  it "holds a key" do
    widget = Qt::Widget.new
    shortcut = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+K"), widget)
    shortcut.key.to_string.should eq("Ctrl+K")
    shortcut.enabled?.should be_true
    shortcut.context.should eq(Qt::ShortcutContext::WindowShortcut)
    shortcut.context = Qt::ShortcutContext::ApplicationShortcut
    shortcut.context.should eq(Qt::ShortcutContext::ApplicationShortcut)
    shortcut.key = Qt::KeySequence.new("F5")
    shortcut.key.to_string.should eq("F5")
    shortcut.parent_widget.should eq(widget)
    standard = Qt::Shortcut.new(Qt::KeySequence.new(Qt::KeySequence::StandardKey::Save), widget)
    standard.key.empty?.should be_false
  end
end

describe Qt::ActionGroup do
  it "makes actions exclusive" do
    group = Qt::ActionGroup.new(Qt::Widget.new)
    one = group.add_action("one").not_nil!
    two = Qt::Action.new("two")
    group.add_action(two)
    one.checkable = true
    two.checkable = true
    group.exclusive?.should be_true
    group.actions.size.should eq(2)
    group.checked_action.should be_nil
    triggered = [] of String
    group.on_triggered { |action| triggered << action.text }
    one.trigger
    one.checked?.should be_true
    two.trigger
    two.checked?.should be_true
    one.checked?.should be_false
    group.checked_action.not_nil!.text.should eq("two")
    triggered.should eq(["one", "two"])
    group.exclusion_policy = Qt::ActionGroup::ExclusionPolicy::None
    group.exclusive?.should be_false
    group.remove_action(two)
    group.actions.size.should eq(1)
  end
end

describe Qt::WidgetAction do
  it "wraps a widget" do
    action = Qt::WidgetAction.new(Qt::Widget.new)
    action.default_widget.should be_nil
    label = Qt::Label.new("inside")
    action.default_widget = label
    action.default_widget.should eq(label)
    menu = Qt::Menu.new
    menu.add_action(action)
    menu.actions.size.should eq(1)
  end
end

describe Qt::ToolTip do
  it "has a font and palette" do
    Qt::ToolTip.visible?.should be_false
    Qt::ToolTip.font.should be_a(Qt::Font)
    Qt::ToolTip.text.should eq("")
    Qt::WhatsThis.in_whats_this_mode.should be_false
    Qt::WhatsThis.create_action.not_nil!.text.should eq("What's This?")
  end
end
