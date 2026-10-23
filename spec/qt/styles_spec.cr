require "../spec_helper"

# The styles, validators and graphics view classes.

# Doubles one pixel metric, leaving the rest to the base style.
private class WideStyle < Qt::ProxyStyle
  def pixel_metric(metric : Qt::Style::PixelMetric, option : Qt::StyleOption? = nil, widget : Qt::Widget? = nil) : Int32
    value = superclass.pixel_metric(metric, option, widget)
    metric == Qt::Style::PixelMetric::ButtonMargin ? value * 2 : value
  end
end

describe Qt::Style do
  it "answers pixel metrics and hints" do
    style = Qt::Application.style.not_nil!
    style.object_name.should_not be_empty
    style.pixel_metric(Qt::Style::PixelMetric::ButtonMargin).should be > 0
    style.pixel_metric(Qt::Style::PixelMetric::DefaultFrameWidth, nil, nil).should be >= 0
    style.style_hint(Qt::Style::StyleHint::ToolTip_WakeUpDelay).should be >= 0
    style.standard_palette.should be_a(Qt::Palette)
    style.standard_icon(Qt::Style::StandardPixmap::DialogOkButton).null?.should be_false
    Qt::Style.slider_value_from_position(0, 100, 50, 100).should eq(50)
    Qt::Style.visual_alignment(Qt::LayoutDirection::LeftToRight, Qt::Alignment::AlignLeft).should eq(Qt::Alignment::AlignLeft | Qt::Alignment::AlignAbsolute)
    rect = Qt::Style.aligned_rect(Qt::LayoutDirection::LeftToRight, Qt::Alignment::AlignCenter, Qt::Size.new(10, 10), Qt::Rect.new(0, 0, 100, 100))
    rect.x.should eq(45)
  end

  it "takes an option" do
    button = Qt::PushButton.new("ok")
    option = Qt::StyleOptionButton.new
    option.init_from(button)
    option.text = "ok"
    option.text.should eq("ok")
    option.features = Qt::StyleOptionButton::ButtonFeatures::Flat
    option.features.should eq(Qt::StyleOptionButton::ButtonFeatures::Flat)
    option.rect.width.should eq(button.width)
    option.type.should eq(Qt::StyleOption::OptionType::Button.to_i)
    option.state.includes?(Qt::Style::State::Enabled).should be_true
    style = Qt::Application.style.not_nil!
    size = style.size_from_contents(Qt::Style::ContentsType::PushButton, option, Qt::Size.new(10, 10), button)
    size.width.should be >= 10
    style.sub_element_rect(Qt::Style::SubElement::PushButtonContents, option, button).width.should be > 0
    hint = Qt::StyleHintReturn.new
    hint.type.should eq(Qt::StyleHintReturn::HintReturnType::Default.to_i)
    complex = Qt::StyleOptionSlider.new
    complex.sub_controls = Qt::Style::SubControls::SliderGroove | Qt::Style::SubControls::SliderHandle
    complex.sub_controls.should eq(Qt::Style::SubControls::SliderGroove | Qt::Style::SubControls::SliderHandle)
    complex.orientation = Qt::Orientation::Vertical
    complex.orientation.should eq(Qt::Orientation::Vertical)
  end

  it "is overridden from Crystal" do
    base = Qt::Application.style.not_nil!
    style = WideStyle.new
    style.base_style.not_nil!.object_name.should eq(base.object_name) # A new instance of the application's style
    margin = base.pixel_metric(Qt::Style::PixelMetric::ButtonMargin)
    style.pixel_metric(Qt::Style::PixelMetric::ButtonMargin).should eq(margin * 2)
    style.pixel_metric(Qt::Style::PixelMetric::DefaultFrameWidth).should eq(base.pixel_metric(Qt::Style::PixelMetric::DefaultFrameWidth))
    button = Qt::PushButton.new("styled")
    button.style = style
    button.style.not_nil!.pixel_metric(Qt::Style::PixelMetric::ButtonMargin).should eq(margin * 2)
    button.style.should eq(style)
  end

  it "comes from a factory" do
    keys = Qt::StyleFactory.keys.to_a
    keys.should contain("Fusion")
    fusion = Qt::StyleFactory.create("Fusion").not_nil!
    fusion.object_name.should eq("fusion")
    Qt::StyleFactory.create("no such style").should be_nil
    hints = Qt::Application.style_hints.not_nil!
    hints.cursor_flash_time.should be >= 0
    hints.tab_focus_behavior.should be_a(Qt::TabFocusBehavior)
    hints.password_mask_character.should be_a(Char)
  end
end

describe Qt::Validator do
  it "validates integers" do
    validator = Qt::IntValidator.new(1, 100)
    validator.bottom.should eq(1)
    validator.top.should eq(100)
    validator.validate("50", 0)[0].should eq(Qt::Validator::State::Acceptable)
    validator.validate("500", 0)[0].should eq(Qt::Validator::State::Intermediate)
    validator.validate("", 0)[0].should eq(Qt::Validator::State::Intermediate)
    validator.validate("-1", 0)[0].should eq(Qt::Validator::State::Invalid)
    validator.validate("x", 0)[0].should eq(Qt::Validator::State::Invalid)
    validator.set_range(0, 5)
    validator.validate("50", 0)[0].should eq(Qt::Validator::State::Invalid) # Can't become valid by typing on
    validator.validate("5", 0)[0].should eq(Qt::Validator::State::Acceptable)
    validator.locale = Qt::Locale.new("C")
    validator.fixup("1,0").should eq("10") # Drops the group separators

    edit = Qt::LineEdit.new
    edit.validator.should be_nil
    edit.validator = validator
    edit.validator.should eq(validator)
    edit.text = "7"
    edit.has_acceptable_input?.should be_false
    edit.text = "4"
    edit.has_acceptable_input?.should be_true
  end

  it "validates doubles" do
    validator = Qt::DoubleValidator.new(0.0, 1.0, 2)
    validator.decimals.should eq(2)
    validator.notation = Qt::DoubleValidator::Notation::StandardNotation
    validator.notation.should eq(Qt::DoubleValidator::Notation::StandardNotation)
    validator.locale = Qt::Locale.new("C")
    validator.validate("0.5", 0)[0].should eq(Qt::Validator::State::Acceptable)
    validator.validate("0.555", 0)[0].should eq(Qt::Validator::State::Invalid)
    validator.validate("5", 0)[0].should eq(Qt::Validator::State::Intermediate)
  end

  it "validates with a regular expression" do
    validator = Qt::RegularExpressionValidator.new(Qt::RegularExpression.new("[a-z]+"))
    validator.regular_expression.pattern.should eq("[a-z]+")
    validator.validate("abc", 0)[0].should eq(Qt::Validator::State::Acceptable)
    validator.validate("ABC", 0)[0].should eq(Qt::Validator::State::Invalid)
    validator.validate("", 0)[0].should eq(Qt::Validator::State::Intermediate)
  end
end

describe Qt::GraphicsProxyWidget do
  it "embeds a widget in a scene" do
    scene = Qt::GraphicsScene.new
    label = Qt::Label.new("embedded")
    proxy = scene.add_widget(label).not_nil!
    proxy.should be_a(Qt::GraphicsProxyWidget)
    proxy.widget.should eq(label)
    Qt::Label.new(unwrap: proxy.widget.not_nil!.to_unsafe.as(Qt::Binding::QLabel*)).text.should eq("embedded")
    scene.items.size.should eq(1)
    proxy.set_pos(10.0, 20.0)
    proxy.pos.x.should eq(10.0)
    proxy.bounding_rect.width.should eq(label.width)

    proxy.graphics_effect.should be_nil
    effect = Qt::GraphicsDropShadowEffect.new
    effect.blur_radius = 4.0
    effect.set_offset(2.0, 3.0)
    effect.color = Qt::Color.new(0, 0, 0, 128)
    proxy.graphics_effect = effect
    proxy.graphics_effect.should eq(effect)
    effect.blur_radius.should eq(4.0)
    effect.offset.should eq(Qt::PointF.new(2.0, 3.0))
    effect.x_offset.should eq(2.0)
    effect.enabled?.should be_true
    effect.bounding_rect_for(Qt::RectF.new(0.0, 0.0, 10.0, 10.0)).width.should be > 10.0

    blur = Qt::GraphicsBlurEffect.new
    blur.blur_hints = Qt::GraphicsBlurEffect::BlurHints::QualityHint
    blur.blur_hints.should eq(Qt::GraphicsBlurEffect::BlurHints::QualityHint)
    opacity = Qt::GraphicsOpacityEffect.new
    opacity.opacity = 0.5
    opacity.opacity.should eq(0.5)
    colorize = Qt::GraphicsColorizeEffect.new
    colorize.strength = 0.25
    colorize.strength.should eq(0.25)
    widget = Qt::Widget.new
    widget.graphics_effect = opacity
    widget.graphics_effect.should eq(opacity)
  end
end

describe Qt::GraphicsLinearLayout do
  it "lays out graphics widgets" do
    scene = Qt::GraphicsScene.new
    form = Qt::GraphicsWidget.new
    scene.add_item(form.as_graphics_item)
    layout = Qt::GraphicsLinearLayout.new(Qt::Orientation::Vertical)
    first = Qt::GraphicsWidget.new
    second = Qt::GraphicsWidget.new
    first.set_preferred_size(50.0, 20.0)
    second.set_preferred_size(50.0, 30.0)
    layout.add_item(first.as_graphics_layout_item) # QGraphicsWidget's second base
    layout.add_item(second.as_graphics_layout_item)
    layout.count.should eq(2)
    layout.orientation.should eq(Qt::Orientation::Vertical)
    layout.item_at(1).not_nil!.to_unsafe.should eq(second.as_graphics_layout_item.to_unsafe)
    layout.set_stretch_factor(second.as_graphics_layout_item, 2)
    layout.stretch_factor(second.as_graphics_layout_item).should eq(2)
    layout.spacing = 5.0
    layout.spacing.should eq(5.0)
    form.layout.should be_nil
    form.layout = layout
    form.layout.not_nil!.to_unsafe.should eq(layout.to_unsafe)
    form.resize(100.0, 100.0)
    first.geometry.width.should be > 50.0 # Less the contents margins
    first.geometry.y.should be < second.geometry.y
    first.parent_layout_item.not_nil!.to_unsafe.should eq(layout.to_unsafe)
    first.size_policy.horizontal_policy.should eq(Qt::SizePolicy::Policy::Preferred)

    grid = Qt::GraphicsGridLayout.new
    grid.add_item(Qt::GraphicsWidget.new.as_graphics_layout_item, 0, 0)
    grid.add_item(Qt::GraphicsWidget.new.as_graphics_layout_item, 1, 1)
    grid.row_count.should eq(2)
    grid.column_count.should eq(2)
    grid.count.should eq(2)

    anchors = Qt::GraphicsAnchorLayout.new
    a = Qt::GraphicsWidget.new.as_graphics_layout_item
    b = Qt::GraphicsWidget.new.as_graphics_layout_item
    anchor = anchors.add_anchor(a, Qt::AnchorPoint::AnchorRight, b, Qt::AnchorPoint::AnchorLeft).not_nil!
    anchor.spacing = 7.0
    anchor.spacing.should eq(7.0)
    anchors.count.should eq(2)
  end

  it "groups and animates items" do
    scene = Qt::GraphicsScene.new
    line = Qt::GraphicsLineItem.new(Qt::LineF.new(0.0, 0.0, 10.0, 0.0))
    line.line.length.should eq(10.0)
    line.set_line(0.0, 0.0, 3.0, 4.0)
    line.line.length.should eq(5.0)
    rect = Qt::GraphicsRectItem.new(Qt::RectF.new(0.0, 0.0, 5.0, 5.0))
    group = scene.create_item_group([line.as(Qt::GraphicsItem), rect.as(Qt::GraphicsItem)]).not_nil!
    group.should be_a(Qt::GraphicsItemGroup)
    group.child_items.size.should eq(2)
    group.remove_from_group(rect)
    group.child_items.size.should eq(1)

    timeline = Qt::TimeLine.new(1000)
    animation = Qt::GraphicsItemAnimation.new
    animation.item.should be_nil
    animation.item = rect
    animation.item.not_nil!.to_unsafe.should eq(rect.as(Qt::GraphicsItem).to_unsafe)
    animation.time_line = timeline
    animation.time_line.should eq(timeline)
    animation.set_pos_at(1.0, Qt::PointF.new(100.0, 50.0))
    animation.set_rotation_at(1.0, 90.0)
    animation.pos_at(0.5).x.should eq(50.0)
    animation.rotation_at(0.5).should eq(45.0)
    animation.pos_list.to_a.should eq([{1.0, Qt::PointF.new(100.0, 50.0)}]) # A QList<QPair>, as tuples
    animation.rotation_list.to_a.should eq([{1.0, 90.0}])
    animation.step = 1.0
    rect.pos.x.should eq(100.0)

    rotation = Qt::GraphicsRotation.new
    rotation.angle = 30.0
    rotation.angle.should eq(30.0)
    rotation.axis = Qt::Axis::YAxis
    scale = Qt::GraphicsScale.new
    scale.x_scale = 2.0
    scale.x_scale.should eq(2.0)
  end
end

describe Qt::GraphicsSceneEvent do
  it "carries positions" do
    event = Qt::GraphicsSceneMouseEvent.new(Qt::Event::Type::GraphicsSceneMousePress)
    event.scene_pos = Qt::PointF.new(1.0, 2.0)
    event.scene_pos.should eq(Qt::PointF.new(1.0, 2.0))
    event.button = Qt::MouseButton::LeftButton
    event.button.should eq(Qt::MouseButton::LeftButton)
    event.type.should eq(Qt::Event::Type::GraphicsSceneMousePress)
    wheel = Qt::GraphicsSceneWheelEvent.new(Qt::Event::Type::GraphicsSceneWheel)
    wheel.delta = 120
    wheel.delta.should eq(120)
    menu = Qt::GraphicsSceneContextMenuEvent.new(Qt::Event::Type::GraphicsSceneContextMenu)
    menu.reason = Qt::GraphicsSceneContextMenuEvent::Reason::Keyboard
    menu.reason.should eq(Qt::GraphicsSceneContextMenuEvent::Reason::Keyboard)
    resize = Qt::GraphicsSceneResizeEvent.new
    resize.new_size = Qt::SizeF.new(3.0, 4.0)
    resize.new_size.height.should eq(4.0)
    hover = Qt::GraphicsSceneHoverEvent.new(Qt::Event::Type::GraphicsSceneHoverMove)
    hover.last_pos = Qt::PointF.new(5.0, 6.0)
    hover.last_pos.y.should eq(6.0)
    event.widget.should be_nil
  end
end

describe Qt::Scroller do
  it "scrolls a widget" do
    area = Qt::ScrollArea.new
    viewport = area.viewport.not_nil!
    Qt::Scroller.has_scroller(viewport).should be_false
    gesture = Qt::Scroller.grab_gesture(viewport, Qt::Scroller::ScrollerGestureType::LeftMouseButtonGesture)
    gesture.to_i.should be >= Qt::GestureType::CustomGesture.to_i # A registered custom gesture
    Qt::Scroller.grabbed_gesture(viewport).should eq(gesture)
    scroller = Qt::Scroller.scroller(viewport).not_nil!
    Qt::Scroller.has_scroller(viewport).should be_true
    scroller.target.should eq(viewport)
    scroller.state.should eq(Qt::Scroller::State::Inactive)
    properties = scroller.scroller_properties
    properties.scroll_metric(Qt::ScrollerProperties::ScrollMetric::FrameRate).is_nil?.should be_false # A QVariant of the FrameRates enum, unknown to Qt::Variant
    properties.set_scroll_metric(Qt::ScrollerProperties::ScrollMetric::DecelerationFactor, Qt.variant(0.5))
    properties.scroll_metric(Qt::ScrollerProperties::ScrollMetric::DecelerationFactor).to(Float64).should eq(0.5)
    scroller.scroller_properties = properties
    scroller.scroller_properties.scroll_metric(Qt::ScrollerProperties::ScrollMetric::DecelerationFactor).to(Float64).should eq(0.5)
    Qt::Scroller.ungrab_gesture(viewport)
  end
end
