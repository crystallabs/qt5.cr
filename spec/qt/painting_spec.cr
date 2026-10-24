require "../spec_helper"

# The painting and geometry classes.

private def white_image(size = 16)
  image = Qt::Image.new(size, size, Qt::Image::Format::Argb32)
  image.fill(Qt::Color.new(255, 255, 255))
  image
end

describe Qt::PainterPath do
  it "draws lines and arcs into an image" do
    path = Qt::PainterPath.new
    path.move_to(2.0, 2.0)
    path.line_to(12.0, 2.0)
    path.arc_to(Qt::RectF.new(2.0, 2.0, 10.0, 10.0), 0.0, -90.0)
    path.close_subpath
    path.empty?.should be_false
    path.element_count.should be > 3
    path.element_at(0).type.should eq(Qt::PainterPath::ElementType::MoveToElement)
    path.element_at(0).x.should eq(2.0) # A copied structure's property method
    path.element_at(0).y.should eq(2.0)
    path.element_at(0).move_to?.should be_true
    path.element_at(1).type.should eq(Qt::PainterPath::ElementType::LineToElement)
    path.element_at(1).to_q_point_f.should eq(Qt::PointF.new(12.0, 2.0))
    path.current_position.should eq(Qt::PointF.new(2.0, 2.0))
    rect = path.bounding_rect
    rect.left.should eq(2.0)
    rect.top.should eq(2.0)
    rect.right.should eq(12.0)
    rect.bottom.should eq(12.0)
    path.contains(Qt::PointF.new(8.0, 4.0)).should be_true
    path.contains(Qt::PointF.new(3.0, 11.0)).should be_false

    image = white_image
    painter = Qt::Painter.new(image)
    painter.fill_path(path, Qt::Brush.new(Qt::Color.new(255, 0, 0)))
    painter.end
    image.pixel_color(8, 4).name.should eq("#ff0000")
    image.pixel_color(3, 11).name.should eq("#ffffff")
  end

  it "is stroked, combined and transformed" do
    path = Qt::PainterPath.new
    path.add_rect(0.0, 0.0, 10.0, 10.0)
    stroker = Qt::PainterPathStroker.new
    stroker.width = 2.0
    outline = stroker.create_stroke(path)
    outline.bounding_rect.width.should eq(12.0)

    other = Qt::PainterPath.new
    other.add_ellipse(Qt::RectF.new(5.0, 5.0, 10.0, 10.0))
    path.intersects(other).should be_true
    path.united(other).bounding_rect.right.should eq(15.0)
    path.intersected(other).bounding_rect.left.should be >= 5.0
    path.to_subpath_polygons.size.should eq(1)
    path.to_fill_polygon.size.should be > 3
  end
end

describe Qt::Transform do
  it "rotates and maps points" do
    transform = Qt::Transform.new
    transform.identity?.should be_true
    transform.rotate(90.0)
    transform.rotating?.should be_true
    point = transform.map(Qt::PointF.new(1.0, 0.0))
    point.x.should be_close(0.0, 1e-9)
    point.y.should be_close(1.0, 1e-9)
    transform.map(Qt::Point.new(10, 0)).should eq(Qt::Point.new(0, 10))
    inverse, invertible = transform.inverted # `bool *invertible` is returned with the result
    inverse.map(Qt::Point.new(0, 10)).should eq(Qt::Point.new(10, 0))
    invertible.should be_true
    inverse, invertible = Qt::Transform.from_scale(0.0, 0.0).inverted
    inverse.identity?.should be_true
    invertible.should be_false
    Qt::Transform.from_translate(3.0, 4.0).map(Qt::Point.new(1, 1)).should eq(Qt::Point.new(4, 5))
    Qt::Transform.from_scale(2.0, 3.0).map_rect(Qt::Rect.new(1, 1, 2, 2)).should eq(Qt::Rect.new(2, 3, 4, 6))
    (Qt::Transform.new * Qt::Transform.from_scale(2.0, 2.0)).m11.should eq(2.0)
    transform.type.should eq(Qt::Transform::TransformationType::TxRotate)

    matrix = Qt::Matrix.new # The affine matrix QTransform replaced
    matrix.translate(1.0, 2.0)
    matrix.map(Qt::Point.new(1, 1)).should eq(Qt::Point.new(2, 3))
    inverse, invertible = matrix.inverted
    inverse.map(Qt::Point.new(2, 3)).should eq(Qt::Point.new(1, 1))
    matrix.invertible?.should be_true
    inverse.dx.should eq(-1.0)
    invertible.should be_true
  end

  it "transforms a painter" do
    image = white_image
    painter = Qt::Painter.new(image)
    painter.set_transform(Qt::Transform.from_translate(8.0, 8.0))
    painter.fill_rect(Qt::Rect.new(0, 0, 4, 4), Qt::Color.new(0, 0, 255))
    painter.end
    image.pixel_color(9, 9).name.should eq("#0000ff")
    image.pixel_color(1, 1).name.should eq("#ffffff")
  end
end

describe Qt::Matrix4x4 do
  it "maps vectors and rotates by quaternions" do
    matrix = Qt::Matrix4x4.new
    matrix.identity?.should be_true
    matrix.translate(1.0_f32, 2.0_f32, 3.0_f32)
    inverse, invertible = matrix.inverted
    inverse.map(Qt::Vector3D.new(2.0_f32, 3.0_f32, 4.0_f32)).x.should eq(1.0_f32)
    invertible.should be_true
    (inverse * matrix).identity?.should be_true
    vector = matrix.map(Qt::Vector3D.new(1.0_f32, 1.0_f32, 1.0_f32))
    {vector.x, vector.y, vector.z}.should eq({2.0_f32, 3.0_f32, 4.0_f32})
    vector.length.should be_close(Math.sqrt(29.0), 1e-5)
    matrix.inverted[0].map(vector).x.should be_close(1.0, 1e-6)
    Qt::Vector3D.new(3.0_f32, 4.0_f32, 0.0_f32).normalized.x.should be_close(0.6, 1e-6)
    Qt::Vector3D.cross_product(Qt::Vector3D.new(1.0_f32, 0.0_f32, 0.0_f32), Qt::Vector3D.new(0.0_f32, 1.0_f32, 0.0_f32)).z.should eq(1.0_f32)
    Qt::Vector2D.new(3.0_f32, 4.0_f32).length.should eq(5.0_f32)
    Qt::Vector4D.new(1.0_f32, 2.0_f32, 3.0_f32, 1.0_f32).to_vector3_d.z.should eq(3.0_f32)

    quaternion = Qt::Quaternion.from_axis_and_angle(Qt::Vector3D.new(0.0_f32, 0.0_f32, 1.0_f32), 90.0_f32)
    rotated = quaternion.rotated_vector(Qt::Vector3D.new(1.0_f32, 0.0_f32, 0.0_f32))
    rotated.x.should be_close(0.0, 1e-6)
    rotated.y.should be_close(1.0, 1e-6)
    rotation = Qt::Matrix4x4.new
    rotation.rotate(quaternion)
    rotation.map(Qt::Vector3D.new(1.0_f32, 0.0_f32, 0.0_f32)).y.should be_close(1.0, 1e-6)
    (rotation * Qt::Vector3D.new(1.0_f32, 0.0_f32, 0.0_f32)).y.should be_close(1.0, 1e-6)
    (Qt::Vector3D.new(1.0_f32, 0.0_f32, 0.0_f32) * rotation).y.should be_close(-1.0, 1e-6) # Row vector: the transpose
  end
end

describe Qt::Gradient do
  it "fills with a linear gradient" do
    gradient = Qt::LinearGradient.new(0.0, 0.0, 16.0, 0.0)
    gradient.set_color_at(0.0, Qt::Color.new(255, 0, 0))
    gradient.set_color_at(1.0, Qt::Color.new(0, 0, 255))
    gradient.type.should eq(Qt::Gradient::Type::LinearGradient)
    gradient.final_stop.should eq(Qt::PointF.new(16.0, 0.0))
    gradient.spread = Qt::Gradient::Spread::PadSpread
    gradient.stops.map { |(position, color)| {position, color.name} }.should eq([{0.0, "#ff0000"}, {1.0, "#0000ff"}])
    gradient.stops = [{0.0, Qt::Color.new(0, 255, 0)}, {1.0, Qt::Color.new(0, 0, 0)}]
    gradient.stops.map(&.[1].green).should eq([255, 0])
    gradient.stops = [{0.0, Qt::Color.new(255, 0, 0)}, {1.0, Qt::Color.new(0, 0, 255)}]

    image = white_image
    painter = Qt::Painter.new(image)
    painter.fill_rect(Qt::Rect.new(0, 0, 16, 16), Qt::Brush.new(gradient))
    painter.end
    left = image.pixel_color(0, 8)
    right = image.pixel_color(15, 8)
    left.red.should be > left.blue
    right.blue.should be > right.red
    image.pixel_color(8, 8).red.should be_close(128, 24)

    radial = Qt::RadialGradient.new(Qt::PointF.new(8.0, 8.0), 8.0)
    radial.radius.should eq(8.0)
    conical = Qt::ConicalGradient.new(8.0, 8.0, 45.0)
    conical.angle.should eq(45.0)
    Qt::Brush.new(radial).style.should eq(Qt::BrushStyle::RadialGradientPattern)
    Qt::Gradient.new(Qt::Gradient::Preset::WarmFlame).type.should eq(Qt::Gradient::Type::LinearGradient)
  end
end

describe Qt::Region do
  it "unites rectangles and tests containment" do
    region = Qt::Region.new(0, 0, 10, 10)
    region.united(Qt::Rect.new(20, 20, 10, 10)).rect_count.should eq(2)
    region |= Qt::Region.new(Qt::Rect.new(20, 20, 10, 10))
    region.rect_count.should eq(2)
    region.contains(Qt::Point.new(5, 5)).should be_true
    region.contains(Qt::Point.new(15, 15)).should be_false
    region.contains(Qt::Rect.new(22, 22, 2, 2)).should be_true
    region.bounding_rect.should eq(Qt::Rect.new(0, 0, 30, 30))
    region.intersected(Qt::Rect.new(5, 5, 20, 20)).bounding_rect.should eq(Qt::Rect.new(5, 5, 20, 20))
    region.subtracted(Qt::Region.new(20, 20, 10, 10)).rect_count.should eq(1)
    region.translated(1, 1).bounding_rect.top_left.should eq(Qt::Point.new(1, 1))
    Qt::Region.new(0, 0, 10, 10, Qt::Region::RegionType::Ellipse).contains(Qt::Point.new(0, 0)).should be_false
    Qt::Region.new.empty?.should be_true

    image = white_image
    painter = Qt::Painter.new(image)
    painter.set_clip_region(region)
    painter.fill_rect(Qt::Rect.new(0, 0, 16, 16), Qt::Color.new(0, 128, 0))
    painter.end
    image.pixel_color(5, 5).name.should eq("#008000")
    image.pixel_color(12, 12).name.should eq("#ffffff")
  end
end

describe Qt::ImageWriter do
  it "round trips a PNG through a buffer" do
    image = white_image(4)
    image.set_pixel_color(1, 2, Qt::Color.new(255, 0, 0))

    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    writer = Qt::ImageWriter.new(buffer, "png".to_slice)
    writer.format.should eq("png".to_slice)
    writer.can_write.should be_true
    writer.write(image).should be_true
    writer.error.should eq(Qt::ImageWriter::ImageWriterError::UnknownError)
    buffer.close
    data = buffer.data
    data.size.should be > 8
    String.new(data[1, 3]).should eq("PNG")
    Qt::ImageWriter.supported_image_formats.map { |f| String.new(f) }.should contain("png")

    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    reader = Qt::ImageReader.new(buffer)
    reader.can_read.should be_true
    reader.format.should eq("png".to_slice)
    reader.size.should eq(Qt::Size.new(4, 4))
    read = reader.read
    read.null?.should be_false
    read.pixel_color(1, 2).name.should eq("#ff0000")
    read.pixel_color(0, 0).name.should eq("#ffffff")
    buffer.close
    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    Qt::ImageReader.image_format(buffer).should eq("png".to_slice)
    buffer.close
    Qt::ImageReader.supported_image_formats.map { |f| String.new(f) }.should contain("png")
  end

  it "plays an animation through a movie" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    writer = Qt::ImageWriter.new(buffer, "png".to_slice)
    image = white_image(2)
    image.fill(Qt::Color.new(255, 0, 0))
    writer.write(image).should be_true
    buffer.close
    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    movie = Qt::Movie.new(buffer, "png".to_slice)
    movie.valid?.should be_true
    movie.state.should eq(Qt::Movie::MovieState::NotRunning)
    movie.jump_to_frame(0).should be_true
    movie.current_image.pixel_color(0, 0).name.should eq("#ff0000")
    movie.current_pixmap.null?.should be_false
    movie.frame_rect.should eq(Qt::Rect.new(0, 0, 2, 2))
    Qt::Movie.supported_formats.map { |f| String.new(f) }.should contain("gif")
  end
end

describe Qt::PdfWriter do
  it "writes a page into a file" do
    dir = Qt::TemporaryDir.new
    path = dir.file_path("page.pdf")
    writer = Qt::PdfWriter.new(path)
    writer.title = "qt5.cr"
    writer.title.should eq("qt5.cr")
    writer.set_page_size(Qt::PageSize.new(Qt::PageSize::PageSizeId::A4)).should be_true
    writer.set_page_orientation(Qt::PageLayout::Orientation::Landscape).should be_true
    writer.set_page_margins(Qt::MarginsF.new(10.0, 10.0, 10.0, 10.0), Qt::PageLayout::Unit::Millimeter).should be_true
    writer.page_layout.page_size.id.should eq(Qt::PageSize::PageSizeId::A4)
    writer.page_layout.orientation.should eq(Qt::PageLayout::Orientation::Landscape)
    writer.page_layout.margins.left.should eq(10.0)
    writer.resolution.should be > 0

    painter = Qt::Painter.new(writer.as_paged_paint_device)
    painter.draw_text(Qt::PointF.new(100.0, 100.0), "Hello")
    painter.draw_rect(Qt::Rect.new(100, 200, 300, 300))
    writer.new_page.should be_true
    painter.draw_line(Qt::Point.new(0, 0), Qt::Point.new(100, 100))
    painter.end
    Qt::FileInfo.new(path).size.should be > 0
    File.read(path).should start_with("%PDF")
  end

  it "describes page sizes and layouts" do
    size = Qt::PageSize.new(Qt::PageSize::PageSizeId::Letter)
    size.valid?.should be_true
    size.name.should start_with("Letter")
    size.size(Qt::PageSize::Unit::Inch).should eq(Qt::SizeF.new(8.5, 11.0))
    size.size_points.should eq(Qt::Size.new(612, 792))
    Qt::PageSize.id(Qt::Size.new(612, 792)).should eq(Qt::PageSize::PageSizeId::Letter)
    Qt::PageSize.key(Qt::PageSize::PageSizeId::A4).should eq("A4")

    layout = Qt::PageLayout.new(size, Qt::PageLayout::Orientation::Portrait, Qt::MarginsF.new(1.0, 2.0, 3.0, 4.0), Qt::PageLayout::Unit::Inch)
    layout.valid?.should be_true
    layout.units.should eq(Qt::PageLayout::Unit::Inch)
    layout.paint_rect.width.should eq(4.5)
    layout.full_rect_points.height.should eq(792)
    layout.margins_points.bottom.should eq(288)
  end
end

describe Qt::Picture do
  it "records and replays painting" do
    picture = Qt::Picture.new
    painter = Qt::Painter.new(picture)
    painter.fill_rect(Qt::Rect.new(0, 0, 8, 8), Qt::Color.new(255, 0, 0))
    painter.end
    picture.null?.should be_false
    picture.size.should be > 0
    picture.bounding_rect.should eq(Qt::Rect.new(0, 0, 8, 8))

    image = white_image
    painter = Qt::Painter.new(image)
    painter.draw_picture(4, 4, picture)
    painter.end
    image.pixel_color(6, 6).name.should eq("#ff0000")
    image.pixel_color(2, 2).name.should eq("#ffffff")

    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    picture.save(buffer).should be_true
    buffer.close
    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    loaded = Qt::Picture.new
    loaded.load(buffer).should be_true
    loaded.bounding_rect.should eq(Qt::Rect.new(0, 0, 8, 8))
  end

  it "caches pixmaps" do
    pixmap = Qt::Pixmap.new(2, 2)
    pixmap.fill(Qt::Color.new(0, 255, 0))
    Qt::PixmapCache.insert("qt5.cr spec", pixmap).should be_true
    found = Qt::Pixmap.new
    Qt::PixmapCache.find("qt5.cr spec", found).should be_true
    found.width.should eq(2)
    key = Qt::PixmapCache.insert(pixmap)
    key.valid?.should be_true
    Qt::PixmapCache.find(key, found).should be_true
    Qt::PixmapCache.remove("qt5.cr spec")
    Qt::PixmapCache.find("qt5.cr spec", found).should be_false
    Qt::PixmapCache.cache_limit.should be > 0
  end
end

describe Qt::PainterPixmapFragment do
  it "draws a fragment of a pixmap" do
    fragment = Qt::PainterPixmapFragment.create(Qt::PointF.new(8.0, 8.0), Qt::RectF.new(0.0, 0.0, 4.0, 4.0))
    fragment.width.should eq(4.0)
    fragment.scale_x.should eq(1.0)
    fragment.opacity = 1.0
    fragment.opacity.should eq(1.0)

    pixmap = Qt::Pixmap.new(4, 4)
    pixmap.fill(Qt::Color.new(255, 0, 0))
    image = white_image
    painter = Qt::Painter.new(image)
    painter.draw_pixmap_fragments(fragment, 1, pixmap)
    painter.end
    image.pixel_color(8, 8).name.should eq("#ff0000") # Centered on the position
    image.pixel_color(2, 2).name.should eq("#ffffff")
  end
end

describe Qt::Rgba64 do
  it "holds 16 bit channels" do
    color = Qt::Rgba64.from_rgba(255_u8, 0_u8, 128_u8, 255_u8)
    color.red.should eq(0xffff)
    color.green.should eq(0)
    color.blue8.should eq(128)
    color.opaque?.should be_true
    color.to_argb32.should eq(0xffff0080_u32)
    half = Qt::Rgba64.from_rgba64(0xffff_u16, 0xffff_u16, 0xffff_u16, 0x8000_u16)
    half.premultiplied.red.should eq(0x8000)
    Qt::Color.new(half).alpha_f.should be_close(0.5, 0.01)
    Qt::Color.new(255, 0, 0).rgba64.red.should eq(0xffff)
  end

  it "describes color spaces" do
    srgb = Qt::ColorSpace.new(Qt::ColorSpace::NamedColorSpace::Srgb)
    srgb.valid?.should be_true
    srgb.primaries.should eq(Qt::ColorSpace::Primaries::Srgb)
    srgb.transfer_function.should eq(Qt::ColorSpace::TransferFunction::Srgb)
    srgb.icc_profile.size.should be > 0
    Qt::ColorSpace.from_icc_profile(srgb.icc_profile).valid?.should be_true
    linear = Qt::ColorSpace.new(Qt::ColorSpace::Primaries::Srgb, Qt::ColorSpace::TransferFunction::Linear)
    linear.gamma.should eq(1.0_f32)
    transform = srgb.transformation_to_color_space(linear)
    transform.map(Qt::Color.new(255, 255, 255)).red.should eq(255)
    transform.map(Qt::Color.new(128, 128, 128)).red.should be < 128 # sRGB mid gray is darker in linear light
  end
end

describe Qt::OffscreenSurface do
  it "has a format and a size" do
    format = Qt::SurfaceFormat.new
    format.depth_buffer_size = 24
    format.depth_buffer_size.should eq(24)
    format.options = Qt::SurfaceFormat::FormatOptions::DebugContext
    format.test_option(Qt::SurfaceFormat::FormatOption::DebugContext).should be_true
    format.set_version(3, 2)
    format.major_version.should eq(3)
    Qt::SurfaceFormat.default_format.renderable_type.should be_a(Qt::SurfaceFormat::RenderableType)

    surface = Qt::OffscreenSurface.new
    surface.surface_class.should eq(Qt::Surface::SurfaceClass::Offscreen)
    surface.format = format
    surface.requested_format.depth_buffer_size.should eq(24)
    surface.valid?.should be_false
    surface.size.should eq(Qt::Size.new(1, 1))
  end

  it "paints raster windows through a backing store" do
    window = Qt::RasterWindow.new
    window.surface_type.should eq(Qt::Surface::SurfaceType::RasterSurface)
    window.resize(Qt::Size.new(20, 10))
    window.width.should eq(20)
    window.as_paint_device.dev_type.should eq(window.dev_type)
    window.logical_dpi_x.should be > 0

    plain = Qt::Window.new
    plain.resize(Qt::Size.new(8, 8))
    store = Qt::BackingStore.new(plain)
    store.window.not_nil!.to_unsafe.should eq(plain.to_unsafe)
    store.resize(Qt::Size.new(8, 8))
    store.size.should eq(Qt::Size.new(8, 8))
    store.has_static_contents?.should be_false
  end
end
