require "../spec_helper"

# The utility classes of QtCore.
describe "Qt::Uuid" do
  it "creates and parses UUIDs" do
    uuid = Qt::Uuid.create_uuid
    uuid.null?.should be_false
    uuid.version.should eq(Qt::Uuid::Version::Random)
    uuid.to_string.should match(/\A\{[0-9a-f-]{36}\}\z/)
    uuid.to_string(Qt::Uuid::StringFormat::WithoutBraces).size.should eq(36)
    Qt::Uuid.new(uuid.to_string).should eq(uuid)
    Qt::Uuid.from_rfc4122(uuid.to_rfc4122).should eq(uuid)
    uuid.to_rfc4122.size.should eq(16)
    Qt::Uuid.new.null?.should be_true
    Qt::Uuid.new("garbage").null?.should be_true

    dns = Qt::Uuid.new("{6ba7b810-9dad-11d1-80b4-00c04fd430c8}")
    dns.version.should eq(Qt::Uuid::Version::Time)
    dns.data1.should eq(0x6ba7b810)
    Qt::Uuid.create_uuid_v5(dns, "www.example.com").to_string.should eq("{2ed6657d-e927-568b-95e1-2665a8aea6a2}")
    Qt::Uuid.create_uuid_v3(dns, "www.example.com").version.should eq(Qt::Uuid::Version::Md5)
  end
end

describe "Qt::UrlQuery" do
  it "builds and parses queries" do
    query = Qt::UrlQuery.new
    query.empty?.should be_true
    query.add_query_item("name", "a b")
    query.add_query_item("x", "1")
    query.add_query_item("x", "2")
    query.query.should eq("name=a b&x=1&x=2")
    query.to_string(Qt::Url::ComponentFormattingOptions::FullyEncoded).should eq("name=a%20b&x=1&x=2")
    query.has_query_item("x").should be_true
    query.query_item_value("x").should eq("1")
    query.all_query_item_values("x").to_a.should eq(["1", "2"])
    query.query_items.to_a.should eq([{"name", "a b"}, {"x", "1"}, {"x", "2"}])

    query.query_items = [{"k", "v"}]
    query.query.should eq("k=v")
    query.remove_query_item("k")
    query.empty?.should be_true

    Qt::UrlQuery.new("a=1&b=%C3%BC").query_item_value("b").should eq("ü")
    Qt::UrlQuery.new(Qt::Url.new("http://host/path?q=crystal")).query_item_value("q").should eq("crystal")
  end
end

describe "Qt::VersionNumber" do
  it "compares versions" do
    old = Qt::VersionNumber.new(5, 9)
    new = Qt::VersionNumber.from_string("5.15.2")
    new.major_version.should eq(5)
    new.minor_version.should eq(15)
    new.micro_version.should eq(2)
    new.segments.to_a.should eq([5, 15, 2])
    new.to_string.should eq("5.15.2")
    (old < new).should be_true
    (new > old).should be_true
    (new == Qt::VersionNumber.new([5, 15, 2])).should be_true
    Qt::VersionNumber.compare(old, new).should be < 0
    old.is_prefix_of(Qt::VersionNumber.new(5, 9, 1)).should be_true
    Qt::VersionNumber.common_prefix(old, new).to_string.should eq("5")
    Qt::VersionNumber.new(1, 0, 0).normalized.segment_count.should eq(1)

    suffix_index = 0
    Qt::VersionNumber.from_string("2.1-beta", pointerof(suffix_index)).to_string.should eq("2.1")
    suffix_index.should eq(3)
    Qt::LibraryInfo.version.major_version.should eq(5)
  end
end

describe "Qt::CryptographicHash" do
  it "hashes data" do
    Qt::CryptographicHash.hash("abc".to_slice, Qt::CryptographicHash::Algorithm::Sha256).hexstring
      .should eq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    Qt::CryptographicHash.hash("abc".to_slice, Qt::CryptographicHash::Algorithm::Md5).hexstring
      .should eq("900150983cd24fb0d6963f7d28e17f72")
    Qt::CryptographicHash.hash_length(Qt::CryptographicHash::Algorithm::Sha1).should eq(20)

    hash = Qt::CryptographicHash.new(Qt::CryptographicHash::Algorithm::Sha1)
    hash.add_data("a".to_slice)
    hash.add_data("bc".to_slice)
    hash.result.hexstring.should eq("a9993e364706816aba3e25717850c26c9cd0d89d")
    hash.reset
    hash.result.hexstring.should eq("da39a3ee5e6b4b0d3255bfef95601890afd80709") # Of nothing

    buffer = Qt::Buffer.new
    buffer.data = "abc".to_slice
    buffer.open(Qt::IODevice::OpenMode::ReadOnly)
    hash.reset
    hash.add_data(buffer).should be_true
    hash.result.hexstring.should eq("a9993e364706816aba3e25717850c26c9cd0d89d")
  end
end

describe "Qt::RandomGenerator" do
  it "generates numbers" do
    a = Qt::RandomGenerator.new(42u32)
    b = Qt::RandomGenerator.new(42u32)
    a.generate.should eq(b.generate)
    (a == b).should be_true
    a.bounded(10).should be < 10
    a.bounded(5, 8).should be >= 5
    a.generate_double.should be < 1.0
    Qt::RandomGenerator.global.not_nil!.generate64.should be_a(UInt64)
    Qt::RandomGenerator.max.should eq(UInt32::MAX)
    Qt::RandomGenerator64.global.not_nil!.generate.should be_a(UInt64)
  end
end

describe "Qt::ElapsedTimer" do
  it "measures time" do
    timer = Qt::ElapsedTimer.new
    timer.valid?.should be_false
    timer.start
    timer.valid?.should be_true
    sleep 20.milliseconds
    timer.elapsed.should be >= 15
    timer.nsecs_elapsed.should be >= 15_000_000
    timer.has_expired(10).should be_true
    timer.has_expired(60_000).should be_false
    timer.restart.should be >= 15
    timer.elapsed.should be < 1000
    timer.invalidate
    timer.valid?.should be_false
    Qt::ElapsedTimer.monotonic?.should be_true
  end
end

describe "Qt::DeadlineTimer" do
  it "counts down" do
    deadline = Qt::DeadlineTimer.new(1000i64)
    deadline.has_expired?.should be_false
    deadline.forever?.should be_false
    deadline.remaining_time.should be <= 1000
    deadline.remaining_time.should be > 0
    deadline.remaining_time_as_duration.should be <= 1.second
    deadline.timer_type.should eq(Qt::TimerType::CoarseTimer)
    Qt::DeadlineTimer.new(Qt::DeadlineTimer::ForeverConstant::Forever).forever?.should be_true
    Qt::DeadlineTimer.new(0i64).has_expired?.should be_true
    Qt::DeadlineTimer.current.remaining_time.should eq(0)
  end
end

describe "Qt::CommandLineParser" do
  it "parses arguments" do
    parser = Qt::CommandLineParser.new
    parser.application_description = "Spec tool"
    verbose = Qt::CommandLineOption.new(["v", "verbose"], "Say more")
    output = Qt::CommandLineOption.new("output", "Output file", "file", "out.txt")
    parser.add_option(verbose).should be_true
    parser.add_options([output]).should be_true
    parser.add_positional_argument("source", "The input")
    parser.add_help_option.names.to_a.should contain("help")

    parser.parse(["spec", "-v", "--output", "x.txt", "in.txt"]).should be_true
    parser.is_set("verbose").should be_true
    parser.is_set(verbose).should be_true
    parser.value("output").should eq("x.txt")
    parser.value(output).should eq("x.txt")
    parser.positional_arguments.to_a.should eq(["in.txt"])
    parser.option_names.to_a.should eq(["v", "output"])
    parser.help_text.should contain("Say more")

    parser.parse(["spec"]).should be_true
    parser.is_set("verbose").should be_false
    parser.value("output").should eq("out.txt")
    parser.parse(["spec", "--nope"]).should be_false
    parser.error_text.should contain("nope")
    parser.unknown_option_names.to_a.should eq(["nope"])

    output.value_name.should eq("file")
    output.default_values.to_a.should eq(["out.txt"])
    output.flags.should eq(Qt::CommandLineOption::Flags::None)
  end
end

describe "Qt::LibraryInfo" do
  it "describes the Qt library" do
    Qt::LibraryInfo.version.to_string.should eq(String.new(Qt.q_version))
    Qt::LibraryInfo.location(Qt::LibraryInfo::LibraryLocation::PrefixPath).should_not be_empty
    String.new(Qt::LibraryInfo.build).should contain("Qt 5")
  end
end

describe Qt::Locale do
  it "parses numbers, reporting the outcome through a bool pointer" do
    locale = Qt::Locale.new("en_US")
    locale.to_int("42").should eq(42) # The `bool *ok = nullptr` defaults to nil
    ok = false
    locale.to_int("42", pointerof(ok)).should eq(42)
    ok.should be_true
    locale.to_int("forty-two", pointerof(ok)).should eq(0)
    ok.should be_false
  end
end

describe "Qt::Collator" do
  it "compares strings by locale" do
    collator = Qt::Collator.new(Qt::Locale.new("en_US"))
    collator.compare("apple", "Banana").should be < 0 # Not by code point
    collator.compare("a", "a").should eq(0)
    collator.call("apple", "Banana").should be_true # Less than
    collator.case_sensitivity = Qt::CaseSensitivity::CaseInsensitive
    collator.compare("ABC", "abc").should eq(0)

    collator.numeric_mode.should be_false
    collator.compare("file10", "file9").should be < 0
    collator.numeric_mode = true
    collator.compare("file10", "file9").should be > 0

    ten = collator.sort_key("file10")
    nine = collator.sort_key("file9")
    ten.compare(nine).should be > 0
    (nine < ten).should be_true
    collator.locale.name.should eq("en_US")
  end
end

describe "Qt::Translator" do
  it "loads nothing by default" do
    translator = Qt::Translator.new
    translator.empty?.should be_true
    translator.load("qt5cr-nonexistent-translation").should be_false
    translator.file_path.should eq("")
    translator.translate("Context".to_unsafe, "Text".to_unsafe).should eq("")
  end
end

describe "Qt::MimeDatabase" do
  it "looks up MIME types" do
    db = Qt::MimeDatabase.new
    png = db.mime_type_for_file("x.png")
    png.valid?.should be_true
    png.name.should eq("image/png")
    png.preferred_suffix.should eq("png")
    png.suffixes.to_a.should contain("png")
    png.glob_patterns.to_a.should contain("*.png")
    png.comment.should_not be_empty
    png.inherits("application/octet-stream").should be_true
    png.default?.should be_false
    (png == db.mime_type_for_name("image/png")).should be_true

    db.mime_type_for_file("x.png", Qt::MimeDatabase::MatchMode::MatchExtension).name.should eq("image/png")
    db.mime_types_for_file_name("x.png").map(&.name).should contain("image/png")
    db.suffix_for_file_name("picture.png").should eq("png")
    db.mime_type_for_data("%PDF-1.4\n".to_slice).name.should eq("application/pdf")
    db.mime_type_for_data(Bytes[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).name.should eq("image/png")
    db.mime_type_for_url(Qt::Url.new("file:///x.txt")).name.should eq("text/plain")
    db.mime_type_for_name("nonexistent/type").valid?.should be_false
    db.all_mime_types.size.should be > 100
  end
end

describe "Qt::OperatingSystemVersion" do
  it "describes the running system" do
    current = Qt::OperatingSystemVersion.current
    current.type.should eq(Qt::OperatingSystemVersion.current_type)
    {% if flag?(:darwin) %}
      current.major_version.should be > 0
      current.name.should_not be_empty
      current.type.should eq(Qt::OperatingSystemVersion::OSType::MacOS)
      (current >= Qt::OperatingSystemVersion.mac_os_sierra).should be_true
      (Qt::OperatingSystemVersion.new(current.type, 1, 0) < current).should be_true
    {% else %}
      current.type.should eq(Qt::OperatingSystemVersion::OSType::Unknown) # Qt 5 knows no version of Linux
    {% end %}
    sierra = Qt::OperatingSystemVersion.mac_os_sierra
    sierra.major_version.should eq(10)
    (Qt::OperatingSystemVersion.new(sierra.type, 10, 11) < sierra).should be_true
  end
end

describe "Qt::SysInfo" do
  it "describes the machine" do
    Qt::SysInfo.kernel_type.should_not be_empty
    Qt::SysInfo.kernel_version.should_not be_empty
    Qt::SysInfo.product_type.should_not be_empty
    Qt::SysInfo.pretty_product_name.should_not be_empty
    Qt::SysInfo.machine_host_name.should_not be_empty
    Qt::SysInfo.build_abi.should contain("64")
    Qt::SysInfo.current_cpu_architecture.should eq(Qt::SysInfo.build_cpu_architecture)
    Qt::SysInfo::Endian::ByteOrder.should eq(Qt::SysInfo::Endian::LittleEndian)
    Qt::SysInfo::Sizes::WordSize.value.should eq(64)
    {% if flag?(:darwin) %}
      Qt::SysInfo.kernel_type.should eq("darwin")
      ["osx", "macos"].should contain(Qt::SysInfo.product_type) # "osx" up to Qt 5
    {% end %}
  end
end

describe "Qt::TimeZone" do
  it "converts between zones" do
    utc = Qt::TimeZone.utc
    utc.valid?.should be_true
    String.new(utc.id).should eq("UTC")
    noon = Qt::DateTime.new(Qt::Date.new(2024, 7, 1), Qt::Time.new(12, 0), Qt::TimeSpec::Utc)
    utc.offset_from_utc(noon).should eq(0)

    berlin = Qt::TimeZone.new("Europe/Berlin".to_slice)
    berlin.valid?.should be_true
    berlin.offset_from_utc(noon).should eq(7200)
    berlin.standard_time_offset(noon).should eq(3600)
    berlin.daylight_time_offset(noon).should eq(3600)
    berlin.is_daylight_time(noon).should be_true
    berlin.has_daylight_time?.should be_true
    berlin.abbreviation(noon).should_not be_empty # "CEST", or "GMT+2" on macOS
    berlin.country.should eq(Qt::Locale::Country::Germany)

    offset = berlin.offset_data(noon)
    offset.offset_from_utc.should eq(7200)
    offset.abbreviation.should eq(berlin.abbreviation(noon))
    offset.at_utc.should eq(noon)
    transition = berlin.next_transition(noon)
    transition.at_utc.to_string(Qt::DateFormat::ISODate).should eq("2024-10-27T01:00:00Z")
    transition.offset_from_utc.should eq(3600)
    berlin.transitions(noon, noon.add_days(365)).map(&.at_utc.date.month).should eq([10, 3])

    local = noon.to_time_zone(berlin)
    local.time_spec.should eq(Qt::TimeSpec::TimeZone)
    local.time.hour.should eq(14)
    local.time_zone.should eq(berlin)
    (local == noon).should be_true # Same instant
    Qt::DateTime.new(Qt::Date.new(2024, 7, 1), Qt::Time.new(14, 0), berlin).to_utc.time.hour.should eq(12)
    Qt::DateTime.from_secs_since_epoch(0, berlin).to_string("yyyy-MM-dd hh:mm").should eq("1970-01-01 01:00")

    Qt::TimeZone.is_time_zone_id_available("Europe/Berlin".to_slice).should be_true
    Qt::TimeZone.available_time_zone_ids.map { |id| String.new(id) }.should contain("Europe/Berlin")
    Qt::TimeZone.new("Nowhere/Nope".to_slice).valid?.should be_false
    Qt::TimeZone.new(-18000).offset_from_utc(noon).should eq(-18000)
    Qt::TimeZone.system_time_zone.valid?.should be_true
  end
end

describe "Qt::Calendar" do
  it "wraps the calendar systems" do
    gregorian = Qt::Calendar.new
    gregorian.valid?.should be_true
    gregorian.gregorian?.should be_true
    gregorian.name.should eq("Gregorian")
    gregorian.days_in_month(2, 2024).should eq(29)
    gregorian.is_leap_year(2023).should be_false
    gregorian.is_date_valid(2023, 2, 29).should be_false

    parts = gregorian.parts_from_date(Qt::Date.new(2024, 2, 29))
    parts.valid?.should be_true
    {parts.year, parts.month, parts.day}.should eq({2024, 2, 29})
    gregorian.date_from_parts(parts).should eq(Qt::Date.new(2024, 2, 29))
    gregorian.date_from_parts(Qt::Calendar::YearMonthDay.new(2024, 3)).should eq(Qt::Date.new(2024, 3, 1))
    gregorian.day_of_week(Qt::Date.new(2024, 2, 29)).should eq(4)
    gregorian.month_name(Qt::Locale.new("en_US"), 2).should eq("February")

    julian = Qt::Calendar.new(Qt::Calendar::System::Julian)
    julian.name.should eq("Julian")
    julian.date_from_parts(2024, 2, 16).should eq(Qt::Date.new(2024, 2, 29)) # 13 days behind
    Qt::Date.new(2024, 2, 29).month(julian).should eq(2)
    Qt::Date.new(2024, 2, 29).day(julian).should eq(16)
    Qt::Date.new(2024, 2, 29).to_string("yyyy-MM-dd", julian).should eq("2024-02-16")
    Qt::Calendar.available_calendars.to_a.should contain("Julian")
  end
end

describe "Qt::RegularExpression" do
  it "matches patterns" do
    re = Qt::RegularExpression.new("(\\d+)-(?<name>\\w+)")
    re.valid?.should be_true
    re.capture_count.should eq(2)
    re.named_capture_groups.to_a.should eq(["", "", "name"])

    match = re.match("id 42-foo, 7-bar")
    match.has_match?.should be_true
    match.captured.should eq("42-foo")
    match.captured(1).should eq("42")
    match.captured("name").should eq("foo")
    match.captured_start.should eq(3)
    match.captured_end("name").should eq(9)
    match.captured_length(1).should eq(2)
    match.last_captured_index.should eq(2)
    match.captured_texts.to_a.should eq(["42-foo", "42", "foo"])
    re.match("nothing").has_match?.should be_false

    names = [] of String
    iterator = re.global_match("id 42-foo, 7-bar")
    while iterator.has_next?
      names << iterator.next.captured("name")
    end
    names.should eq(["foo", "bar"])

    insensitive = Qt::RegularExpression.new("^crystal$", Qt::RegularExpression::PatternOptions::CaseInsensitiveOption)
    insensitive.match("CRYSTAL").has_match?.should be_true
    insensitive.pattern_options.should eq(Qt::RegularExpression::PatternOptions::CaseInsensitiveOption)
    Qt::RegularExpression.escape("a.b*c").should eq("a\\.b\\*c")
    Qt::RegularExpression.new(Qt::RegularExpression.wildcard_to_regular_expression("*.png")).match("x.png").has_match?.should be_true
    Qt::RegularExpression.anchored_pattern("x").should eq("\\A(?:x)\\z")

    bad = Qt::RegularExpression.new("(unclosed")
    bad.valid?.should be_false
    bad.error_string.should_not be_empty
    bad.pattern_error_offset.should eq(9)
  end
end
