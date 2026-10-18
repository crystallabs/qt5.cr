require "../spec_helper"

# The item models, selections and animations of QtCore and QtGui.
private DISPLAY = Qt::ItemDataRole::DisplayRole.value.to_i
private EDIT    = Qt::ItemDataRole::EditRole.value.to_i

# A read-only list model implemented in Crystal.
private class WordsModel < Qt::AbstractListModel
  def initialize(@words : Array(String))
    super()
  end

  def row_count(parent : Qt::ModelIndex) : Int32
    parent.valid? ? 0 : @words.size
  end

  def data(index : Qt::ModelIndex, role : Int32 = 0) : Qt::Variant
    return Qt.variant(nil) unless role == DISPLAY
    Qt.variant(@words[index.row])
  end
end

private def rows_of(model, column = 0)
  (0...model.row_count).map { |row| model.data(model.index(row, column)).to(String) }
end

private def run_until_quit(timeout = 5000, &)
  loop = Qt::EventLoop.new
  guard = Qt::Timer.new
  guard.single_shot = true
  guard.on_timeout { loop.quit }
  guard.start(timeout)
  yield loop
  loop.exec
  guard.active?.should be_true # Quit before the guard fired
end

describe "Qt::StandardItem" do
  it "builds a tree in a model" do
    model = Qt::StandardItemModel.new
    parent = Qt::StandardItem.new("parent")
    child = Qt::StandardItem.new("child")
    parent.append_row(child)
    parent.append_row([Qt::StandardItem.new("left"), Qt::StandardItem.new("right")])
    model.append_row(parent)
    model.append_row([Qt::StandardItem.new("a"), Qt::StandardItem.new("b")])
    model.horizontal_header_labels = ["Name", "Other"]

    model.row_count.should eq(2)
    model.column_count.should eq(2)
    model.item(0).text.should eq("parent")
    model.item(1, 1).text.should eq("b")
    model.horizontal_header_item(1).text.should eq("Other")
    parent.row_count.should eq(2)
    parent.column_count.should eq(2)
    parent.child(0).text.should eq("child")
    parent.child(1, 1).text.should eq("right")
    parent.has_children?.should be_true
    child.parent.text.should eq("parent")
    child.row.should eq(0)
    child.index.parent.should eq(parent.index)
    child.model.should eq(model)
    model.item_from_index(model.index(0, 0)).text.should eq("parent")
    model.index_from_item(child).should eq(child.index)
    model.data(child.index).to(String).should eq("child")
    model.find_items("child", Qt::MatchFlags::MatchRecursive).map(&.text).should eq(["child"])
    model.find_items("child").should be_empty # Top level only

    child.set_data(Qt.variant("edited"), EDIT)
    child.text.should eq("edited")
    child.data(DISPLAY).to(String).should eq("edited")
    child.set_data(Qt.variant(42), Qt::ItemDataRole::UserRole.value.to_i)
    child.data(Qt::ItemDataRole::UserRole.value.to_i).to(Int32).should eq(42)
    child.checkable = true
    child.check_state = Qt::CheckState::Checked
    child.check_state.should eq(Qt::CheckState::Checked)
    child.flags.should eq(Qt::ItemFlags::ItemIsSelectable | Qt::ItemFlags::ItemIsEditable | Qt::ItemFlags::ItemIsDragEnabled | Qt::ItemFlags::ItemIsDropEnabled | Qt::ItemFlags::ItemIsUserCheckable | Qt::ItemFlags::ItemIsEnabled)
    child.editable = false
    child.editable?.should be_false

    changed = [] of String
    model.on_item_changed { |item| changed << item.text }
    child.text = "again"
    changed.should eq(["again"])

    parent.take_child(0).text.should eq("again")
    parent.row_count.should eq(2)
    parent.sort_children(0)
    model.take_row(1).map(&.text).should eq(["a", "b"])
    model.row_count.should eq(1)
    model.clear
    model.row_count.should eq(0)
    model.invisible_root_item.row_count.should eq(0)
  end
end

describe "Qt::StringListModel" do
  it "models a list of strings" do
    model = Qt::StringListModel.new(["pear", "apple"])
    model.row_count.should eq(2)
    model.column_count.should eq(1)
    rows_of(model).should eq(["pear", "apple"])
    model.string_list.to_a.should eq(["pear", "apple"])

    model.set_data(model.index(0, 0), Qt.variant("plum")).should be_true
    model.insert_rows(2, 1).should be_true
    model.set_data(model.index(2, 0), Qt.variant("fig")).should be_true
    rows_of(model).should eq(["plum", "apple", "fig"])
    model.sort(0)
    rows_of(model).should eq(["apple", "fig", "plum"])
    model.remove_rows(0, 2).should be_true
    model.string_list = ["x"]
    rows_of(model).should eq(["x"])
    (model.flags(model.index(0, 0)) & Qt::ItemFlags::ItemIsEditable).should eq(Qt::ItemFlags::ItemIsEditable)
  end
end

describe "Qt::AbstractListModel" do
  it "is implemented in Crystal" do
    model = WordsModel.new(["one", "two", "three"])
    model.row_count.should eq(3)
    model.column_count.should eq(1)
    rows_of(model).should eq(["one", "two", "three"])
    model.data(model.index(1, 0), EDIT).is_nil?.should be_true
    model.index(2, 0).valid?.should be_true
    model.index(3, 0).valid?.should be_false
    model.has_index(0, 0).should be_true

    view = Qt::ListView.new
    view.model = model
    view.model.row_count.should eq(3)
  end
end

describe "Qt::PersistentModelIndex" do
  it "follows its item" do
    model = Qt::StringListModel.new(["a", "b", "c"])
    persistent = Qt::PersistentModelIndex.new(model.index(2, 0))
    persistent.valid?.should be_true
    persistent.row.should eq(2)
    (persistent == model.index(2, 0)).should be_true
    model.remove_rows(0, 1)
    persistent.row.should eq(1)
    persistent.to_q_model_index.should eq(model.index(1, 0))
    persistent.model.should eq(model)
    model.remove_rows(1, 1)
    persistent.valid?.should be_false
    Qt::PersistentModelIndex.new.valid?.should be_false
  end
end

describe "Qt::ItemSelection" do
  it "is a list of ranges" do
    model = Qt::StandardItemModel.new(3, 2)
    selection = Qt::ItemSelection.new(model.index(0, 0), model.index(1, 1))
    selection.size.should eq(1)
    range = selection[0]
    range.should be_a(Qt::ItemSelectionRange)
    range.top.should eq(0)
    range.bottom.should eq(1)
    range.left.should eq(0)
    range.right.should eq(1)
    range.height.should eq(2)
    range.width.should eq(2)
    range.top_left.should eq(model.index(0, 0))
    range.bottom_right.to_q_model_index.should eq(model.index(1, 1))
    range.contains(model.index(1, 0)).should be_true
    range.contains(model.index(2, 0)).should be_false
    range.model.should eq(model)
    selection.indexes.size.should eq(4)
    selection.contains(model.index(1, 1)).should be_true
    selection.contains(model.index(2, 1)).should be_false

    selection << Qt::ItemSelectionRange.new(model.index(2, 1))
    selection.size.should eq(2)
    selection.map(&.height).should eq([2, 1])
    selection.indexes.map { |index| {index.row, index.column} }.should eq([{0, 0}, {0, 1}, {1, 0}, {1, 1}, {2, 1}])
    selection.select(model.index(2, 0), model.index(2, 0))
    selection.size.should eq(3)
    Qt::ItemSelection.new.should be_empty
    Qt::ItemSelectionRange.new(model.index(0, 0)).intersects(range).should be_true
    Qt::ItemSelectionRange.new(model.index(2, 0)).intersected(range).valid?.should be_false
  end
end

describe "Qt::ItemSelectionModel" do
  it "selects indexes" do
    model = Qt::StandardItemModel.new(3, 2)
    selection_model = Qt::ItemSelectionModel.new(model)
    selection_model.model.should eq(model)
    selection_model.has_selection?.should be_false

    changes = [] of {Int32, Int32}
    selection_model.on_selection_changed { |selected, deselected| changes << {selected.indexes.size, deselected.indexes.size} }

    selection_model.select(model.index(0, 0), Qt::ItemSelectionModel::SelectionFlags::Select)
    selection_model.is_selected(model.index(0, 0)).should be_true
    selection_model.is_selected(model.index(0, 1)).should be_false
    selection_model.selected_indexes.map { |index| {index.row, index.column} }.should eq([{0, 0}])
    changes.should eq([{1, 0}])

    selection_model.select(Qt::ItemSelection.new(model.index(1, 0), model.index(2, 1)), Qt::ItemSelectionModel::SelectionFlags::Select)
    selection_model.selected_indexes.size.should eq(5)
    selection_model.selected_rows(0).map(&.row).should eq([1, 2])
    selection_model.selected_columns(0).map(&.column).should eq([0]) # All of column 0 is selected
    selection_model.is_column_selected(1).should be_false
    selection_model.is_row_selected(1).should be_true
    selection_model.row_intersects_selection(0).should be_true
    selection_model.selection.size.should eq(2)
    selection_model.selection.should be_a(Qt::ItemSelection)

    selection_model.select(model.index(0, 0), Qt::ItemSelectionModel::SelectionFlags::Deselect)
    selection_model.selected_indexes.size.should eq(4)
    selection_model.set_current_index(model.index(2, 1), Qt::ItemSelectionModel::SelectionFlags::Current)
    selection_model.current_index.should eq(model.index(2, 1))
    selection_model.select(model.index(0, 1), Qt::ItemSelectionModel::SelectionFlags::ClearAndSelect)
    selection_model.selected_indexes.map { |index| {index.row, index.column} }.should eq([{0, 1}])
    selection_model.clear_selection
    selection_model.has_selection?.should be_false
    changes.size.should eq(5)

    view = Qt::ListView.new
    view.model = model
    view.selection_model.model.should eq(model)
    view.selection_model = selection_model
    view.selection_model.should eq(selection_model)
  end
end

describe "Qt::SortFilterProxyModel" do
  it "sorts and filters a model" do
    source = Qt::StandardItemModel.new(4, 1)
    ["pear", "Apple", "fig", "apricot"].each_with_index do |name, row|
      source.set_data(source.index(row, 0), Qt.variant(name)).should be_true
    end
    proxy = Qt::SortFilterProxyModel.new
    proxy.source_model = source
    proxy.source_model.should eq(source)
    rows_of(proxy).should eq(["pear", "Apple", "fig", "apricot"])

    proxy.sort(0)
    proxy.sort_column.should eq(0)
    rows_of(proxy).should eq(["Apple", "apricot", "fig", "pear"])
    proxy.sort(0, Qt::SortOrder::DescendingOrder)
    proxy.sort_order.should eq(Qt::SortOrder::DescendingOrder)
    rows_of(proxy).should eq(["pear", "fig", "apricot", "Apple"])
    proxy.sort_case_sensitivity = Qt::CaseSensitivity::CaseSensitive
    proxy.sort(0)
    rows_of(proxy).should eq(["Apple", "apricot", "fig", "pear"])
    proxy.map_to_source(proxy.index(0, 0)).row.should eq(1)
    proxy.map_from_source(source.index(0, 0)).row.should eq(3)
    proxy.map_selection_to_source(Qt::ItemSelection.new(proxy.index(0, 0), proxy.index(0, 0)))[0].top.should eq(1)

    proxy.filter_fixed_string = "ap"
    rows_of(proxy).should eq(["apricot"])
    proxy.filter_case_sensitivity = Qt::CaseSensitivity::CaseInsensitive
    rows_of(proxy).should eq(["Apple", "apricot"])
    proxy.filter_regular_expression = Qt::RegularExpression.new("r$")
    rows_of(proxy).should eq(["pear"])
    proxy.filter_regular_expression.pattern.should eq("r$")
    proxy.filter_wildcard = "*i*"
    rows_of(proxy).should eq(["apricot", "fig"])
    proxy.filter_regular_expression = ""
    proxy.row_count.should eq(4)

    source.set_data(source.index(0, 0), Qt.variant("zebra"))
    proxy.dynamic_sort_filter.should be_true
    rows_of(proxy).should eq(["Apple", "apricot", "fig", "zebra"])
    proxy.set_data(proxy.index(0, 0), Qt.variant("Aardvark")).should be_true
    source.data(source.index(1, 0)).to(String).should eq("Aardvark")
    proxy.invalidate
    proxy.row_count.should eq(4)

    identity = Qt::IdentityProxyModel.new
    identity.source_model = source
    rows_of(identity).should eq(rows_of(source))
    identity.map_to_source(identity.index(2, 0)).should eq(source.index(2, 0))
    identity.map_from_source(source.index(3, 0)).row.should eq(3)
  end
end

describe "Qt::FileSystemModel" do
  it "models a directory" do
    dir = Qt::TemporaryDir.new
    begin
      ::File.write(dir.file_path("b.txt"), "12345")
      ::Dir.mkdir(dir.file_path("sub"))
      model = Qt::FileSystemModel.new
      model.read_only?.should be_true
      model.filter = Qt::Dir::Filters::AllEntries | Qt::Dir::Filters::NoDotAndDotDot
      loaded = [] of String
      model.on_directory_loaded { |path| loaded << path }
      root = model.set_root_path(dir.path)
      model.root_path.should eq(dir.path)
      model.root_directory.path.should eq(dir.path)
      root.valid?.should be_true
      model.file_path(root).should eq(dir.path)
      run_until_quit { |loop| model.on_directory_loaded { loop.quit } }
      loaded.should eq([dir.path])

      model.row_count(root).should eq(2)
      names = (0...model.row_count(root)).map { |row| model.file_name(model.index(row, 0, root)) }
      names.sort.should eq(["b.txt", "sub"])
      file = model.index(dir.file_path("b.txt"))
      file.valid?.should be_true
      model.is_dir(file).should be_false
      model.size(file).should eq(5)
      model.file_info(file).suffix.should eq("txt")
      model.last_modified(file).valid?.should be_true
      model.data(file).to(String).should eq("b.txt")
      model.data(file, Qt::FileSystemModel::Roles::FilePathRole.value.to_i).to(String).should eq(dir.file_path("b.txt"))
      model.is_dir(model.index(dir.file_path("sub"))).should be_true
      model.column_count(root).should eq(4)
      model.header_data(0, Qt::Orientation::Horizontal).to(String).should eq("Name")
      model.type(file).should_not be_empty
    ensure
      dir.remove
    end
  end
end

describe "Qt::EasingCurve" do
  it "maps progress to a value" do
    linear = Qt::EasingCurve.new
    linear.type.should eq(Qt::EasingCurve::Type::Linear)
    linear.value_for_progress(0.3).should eq(0.3)

    curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::InOutQuad)
    curve.value_for_progress(0.0).should eq(0.0)
    curve.value_for_progress(0.5).should eq(0.5)
    curve.value_for_progress(1.0).should eq(1.0)
    curve.value_for_progress(0.25).should be < 0.25
    curve.value_for_progress(0.75).should be > 0.75
    (curve == Qt::EasingCurve.new(Qt::EasingCurve::Type::InOutQuad)).should be_true
    (curve == linear).should be_false

    curve.type = Qt::EasingCurve::Type::OutElastic
    curve.amplitude = 2.0
    curve.period = 0.5
    curve.amplitude.should eq(2.0)
    curve.period.should eq(0.5)
    curve.value_for_progress(1.0).should be_close(1.0, 1e-9)

    bezier = Qt::EasingCurve.new(Qt::EasingCurve::Type::BezierSpline)
    bezier.add_cubic_bezier_segment(Qt::PointF.new(0.0, 0.0), Qt::PointF.new(1.0, 1.0), Qt::PointF.new(1.0, 1.0))
    bezier.to_cubic_spline.size.should eq(3)
    bezier.value_for_progress(0.5).should be_close(0.5, 0.01)
  end
end

describe "Qt::VariantAnimation" do
  it "interpolates values" do
    animation = Qt::VariantAnimation.new
    animation.start_value = Qt.variant(0.0)
    animation.end_value = Qt.variant(10.0)
    animation.duration = 1000
    animation.easing_curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::Linear)
    animation.state.should eq(Qt::AbstractAnimation::State::Stopped)
    animation.current_time = 500
    animation.current_value.to(Float64).should eq(5.0)
    animation.current_time = 1000
    animation.current_value.to(Float64).should eq(10.0)

    animation.set_key_value_at(0.5, Qt.variant(2.0))
    animation.key_value_at(0.5).to(Float64).should eq(2.0)
    animation.key_values.map(&.first).should eq([0.0, 0.5, 1.0])
    animation.key_values.map(&.second.to(Float64)).should eq([0.0, 2.0, 10.0])
    animation.current_time = 250
    animation.current_value.to(Float64).should eq(1.0)

    points = Qt::VariantAnimation.new
    points.start_value = Qt.variant(Qt::Point.new(0, 0))
    points.end_value = Qt.variant(Qt::Point.new(100, 50))
    points.duration = 100
    points.easing_curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::Linear)
    points.current_time = 50
    points.current_value.to(Qt::Point).should eq(Qt::Point.new(50, 25))
  end
end

describe "Qt::SequentialAnimationGroup" do
  it "runs property animations one after the other" do
    first = Qt::ProgressBar.new
    second = Qt::ProgressBar.new
    first.value = 0
    second.value = 0

    group = Qt::SequentialAnimationGroup.new
    animations = [first, second].map do |bar|
      animation = Qt::PropertyAnimation.new(bar, "value".to_slice)
      animation.target_object.should eq(bar)
      String.new(animation.property_name).should eq("value")
      animation.start_value = Qt.variant(0)
      animation.end_value = Qt.variant(100)
      animation.duration = 60
      group.add_animation(animation)
      animation
    end
    pause = group.add_pause(30)
    pause.should be_a(Qt::PauseAnimation)
    pause.duration.should eq(30)
    group.animation_count.should eq(3)
    group.duration.should eq(150)
    group.total_duration.should eq(150)
    group.animation_at(0).should eq(animations[0])
    group.index_of_animation(animations[1]).should eq(1)
    animations[0].group.should eq(group)

    order = [] of Int32
    group.on_current_animation_changed { |animation| order << group.index_of_animation(animation) }
    changes = 0
    animations[1].on_value_changed { changes += 1 }
    states = [] of Qt::AbstractAnimation::State
    group.on_state_changed { |new_state, _old_state| states << new_state }

    run_until_quit do |loop|
      group.on_finished { loop.quit }
      group.start
      group.state.should eq(Qt::AbstractAnimation::State::Running)
      first.value.should eq(0) # Only once the loop runs
    end

    group.state.should eq(Qt::AbstractAnimation::State::Stopped)
    first.value.should eq(100)
    second.value.should eq(100)
    order.should eq([1, 2]) # The first was made current when added
    changes.should be > 1
    states.should eq([Qt::AbstractAnimation::State::Running, Qt::AbstractAnimation::State::Stopped])
    group.current_time.should eq(150)

    parallel = Qt::ParallelAnimationGroup.new
    parallel.add_animation(group.take_animation(0))
    parallel.add_animation(Qt::PauseAnimation.new(200))
    parallel.duration.should eq(200)
    group.animation_count.should eq(2)
    parallel.loop_count = 2
    parallel.total_duration.should eq(400)
    parallel.direction = Qt::AbstractAnimation::Direction::Backward
    parallel.direction.should eq(Qt::AbstractAnimation::Direction::Backward)
    parallel.clear
    parallel.animation_count.should eq(0)
  end
end

describe "Qt::TimeLine" do
  it "runs through frames" do
    timeline = Qt::TimeLine.new(1000)
    timeline.duration.should eq(1000)
    timeline.set_frame_range(0, 100)
    timeline.start_frame.should eq(0)
    timeline.end_frame.should eq(100)
    timeline.easing_curve.type.should eq(Qt::EasingCurve::Type::InOutSine) # Qt 5's default
    timeline.easing_curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::Linear)
    timeline.frame_for_time(500).should eq(50)
    timeline.value_for_time(250).should eq(0.25)
    timeline.frame_for_time(250).should eq(25)
    timeline.state.should eq(Qt::TimeLine::State::NotRunning)

    timeline.duration = 50
    timeline.update_interval = 5
    frames = [] of Int32
    timeline.on_frame_changed { |frame| frames << frame }
    run_until_quit do |loop|
      timeline.on_finished { loop.quit }
      timeline.start
      timeline.state.should eq(Qt::TimeLine::State::Running)
    end
    timeline.state.should eq(Qt::TimeLine::State::NotRunning)
    timeline.current_frame.should eq(100)
    timeline.current_value.should eq(1.0)
    frames.last.should eq(100)
    frames.should eq(frames.sort)
    timeline.toggle_direction
    timeline.direction.should eq(Qt::TimeLine::Direction::Backward)
  end
end
