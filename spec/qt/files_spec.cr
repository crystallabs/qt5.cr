require "../spec_helper"

# The file classes of QtCore: files are read and written as `Bytes`, like any
# `Qt::IODevice`.
private def with_temp_dir(&)
  dir = Qt::TemporaryDir.new(::File.join(Qt::Dir.temp_path, "qt5cr-files-XXXXXX"))
  dir.valid?.should be_true
  begin
    yield dir.path
  ensure
    dir.remove.should be_true
    ::Dir.exists?(dir.path).should be_false
  end
end

describe "Qt::File" do
  it "writes and reads bytes" do
    with_temp_dir do |root|
      path = ::File.join(root, "data.bin")
      file = Qt::File.new(path)
      file.exists.should be_false
      file.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      file.write(Bytes[0, 1, 2, 255]).should eq(4)
      file.write("text".to_slice).should eq(4)
      file.close
      file.open?.should be_false
      file.size.should eq(8)

      file.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
      file.read(4).should eq(Bytes[0, 1, 2, 255])
      file.pos.should eq(4)
      String.new(file.read_all).should eq("text")
      file.at_end.should be_true
      file.close

      Qt::File.exists(path).should be_true
      ::File.read(path).to_slice.should eq(Bytes[0, 1, 2, 255, 0x74, 0x65, 0x78, 0x74])
      file.copy(::File.join(root, "copy.bin")).should be_true
      file.rename(::File.join(root, "renamed.bin")).should be_true
      file.file_name.should eq(::File.join(root, "renamed.bin"))
      Qt::File.remove(::File.join(root, "copy.bin")).should be_true
      file.remove.should be_true
      Qt::File.exists(path).should be_false
    end
  end

  it "reports errors" do
    file = Qt::File.new("/nonexistent/qt5cr/file")
    file.open(Qt::IODevice::OpenMode::ReadOnly).should be_false
    file.error.should eq(Qt::FileDevice::FileError::OpenError)
    file.error_string.should_not be_empty
    file.unset_error
    file.error.should eq(Qt::FileDevice::FileError::NoError)
  end
end

describe "Qt::FileInfo" do
  it "describes a file" do
    with_temp_dir do |root|
      path = ::File.join(root, "archive.tar.gz")
      ::File.write(path, "12345")
      info = Qt::FileInfo.new(path)
      info.exists.should be_true
      info.file?.should be_true
      info.dir?.should be_false
      info.size.should eq(5)
      info.file_name.should eq("archive.tar.gz")
      info.base_name.should eq("archive")
      info.complete_base_name.should eq("archive.tar")
      info.suffix.should eq("gz")
      info.complete_suffix.should eq("tar.gz")
      info.absolute_path.should eq(root)
      info.dir.path.should eq(root)
      info.readable?.should be_true
      info.permission(Qt::FileDevice::Permissions::ReadOwner).should be_true
      info.last_modified.valid?.should be_true
      (info.last_modified.secs_to(Qt::DateTime.current_date_time)).should be < 60

      Qt::FileInfo.new(root).dir?.should be_true
      Qt::FileInfo.exists(::File.join(root, "missing")).should be_false
      Qt::FileInfo.new(Qt::File.new(path)).should eq(info)

      infos = Qt::Dir.new(root).entry_info_list(Qt::Dir::Filters::Files)
      infos.map(&.file_name).should eq(["archive.tar.gz"])
    end
  end
end

describe "Qt::TemporaryFile" do
  it "creates a file that goes away with it" do
    file = Qt::TemporaryFile.new(::File.join(Qt::Dir.temp_path, "qt5cr-XXXXXX.txt"))
    file.auto_remove.should be_true
    file.open.should be_true
    name = file.file_name
    name.should_not be_empty
    name.should end_with(".txt")
    ::File.exists?(name).should be_true
    file.write("hello".to_slice).should eq(5)
    file.close
    ::File.read(name).should eq("hello")
    file.delete_later # Qt's destructor removes the file
    Qt::CoreApplication.send_posted_events(nil, Qt::Event::Type::DeferredDelete.value.to_i)
    ::File.exists?(name).should be_false
  end
end

describe "Qt::Settings" do
  it "writes and reads an INI file" do
    with_temp_dir do |root|
      path = ::File.join(root, "app.ini")
      settings = Qt::Settings.new(path, Qt::Settings::Format::IniFormat)
      settings.format.should eq(Qt::Settings::Format::IniFormat)
      settings.set_value("window/title", Qt.variant("Hello"))
      settings.sync
      settings.status.should eq(Qt::Settings::Status::NoError)
      ::File.exists?(path).should be_true
      ::File.read(path).should contain("title=Hello")
      Qt::Settings.new(path, Qt::Settings::Format::IniFormat).value("window/title").to?(String).should eq("Hello")
    end
  end

  it "groups keys" do
    with_temp_dir do |root|
      settings = Qt::Settings.new(::File.join(root, "app.ini"), Qt::Settings::Format::IniFormat)
      settings.begin_group("window")
      settings.set_value("width", Qt.variant(640))
      settings.end_group
      settings.contains("window/width").should be_true
      settings.child_groups.to_a.should eq(["window"])
      settings.value("missing", Qt.variant(1)).to?(Int32).should eq(1)
      settings.remove("window")
      settings.all_keys.to_a.should be_empty
    end
  end
end

describe "Qt::TemporaryDir" do
  it "creates a directory and removes it" do
    dir = Qt::TemporaryDir.new
    dir.valid?.should be_true
    dir.auto_remove.should be_true
    ::Dir.exists?(dir.path).should be_true
    dir.file_path("x").should eq(::File.join(dir.path, "x"))
    ::File.write(dir.file_path("x"), "")
    dir.remove.should be_true
    ::Dir.exists?(dir.path).should be_false
  end
end

describe "Qt::SaveFile" do
  it "replaces the file only on commit" do
    with_temp_dir do |root|
      path = ::File.join(root, "settings.txt")
      ::File.write(path, "old")

      file = Qt::SaveFile.new(path)
      file.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      file.write("discarded".to_slice)
      file.cancel_writing
      file.commit.should be_false
      ::File.read(path).should eq("old")

      file = Qt::SaveFile.new(path)
      file.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      file.write("new".to_slice).should eq(3)
      ::File.read(path).should eq("old") # Not yet
      file.commit.should be_true
      ::File.read(path).should eq("new")
    end
  end
end

describe "Qt::TextStream" do
  it "writes to and reads from a buffer" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::ReadWrite).should be_true
    stream = Qt::TextStream.new(buffer)
    stream << "answer: " << 42 << ' ' << 1.5 << "\n" << "ünïcödé\n"
    stream.flush
    String.new(buffer.data).should eq("answer: 42 1.5\nünïcödé\n")

    stream.seek(0).should be_true
    stream.read_line.should eq("answer: 42 1.5")
    stream.read_line.should eq("ünïcödé")
    stream.at_end.should be_true
    stream.status.should eq(Qt::TextStream::Status::Ok)

    stream.seek(0)
    stream.read(7).should eq("answer:")
    stream.skip_white_space
    number = 0
    stream >> pointerof(number)
    number.should eq(42)
    stream.read_all.should eq(" 1.5\nünïcödé\n")
  end

  it "formats numbers" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly)
    stream = Qt::TextStream.new(buffer)
    stream.field_width = 6
    stream.pad_char = '.'
    stream.field_alignment = Qt::TextStream::FieldAlignment::AlignRight
    stream.integer_base = 16
    stream.number_flags = Qt::TextStream::NumberFlags::ShowBase | Qt::TextStream::NumberFlags::UppercaseDigits
    stream << 255
    stream.flush
    String.new(buffer.data).should eq("..0xFF")
  end

  it "reads a byte array" do
    stream = Qt::TextStream.new("one\ntwo\n".to_slice)
    stream.read_line.should eq("one")
    stream.read_line.should eq("two")
    stream.read_line.should eq("")
    stream.at_end.should be_true
  end
end

describe "Qt::DirIterator" do
  it "walks a tree" do
    with_temp_dir do |root|
      ::Dir.mkdir(::File.join(root, "sub"))
      ::File.write(::File.join(root, "a.txt"), "")
      ::File.write(::File.join(root, "sub", "b.txt"), "")
      ::File.write(::File.join(root, "sub", "c.log"), "")

      names = [] of String
      iterator = Qt::DirIterator.new(root, ["*.txt"], Qt::Dir::Filters::Files, Qt::DirIterator::IteratorFlags::Subdirectories)
      while iterator.has_next?
        iterator.next
        iterator.file_info.file?.should be_true
        names << iterator.file_name
      end
      names.sort.should eq(["a.txt", "b.txt"])

      shallow = Qt::DirIterator.new(root, Qt::Dir::Filters::Files)
      count = 0
      while shallow.has_next?
        shallow.next
        count += 1
      end
      count.should eq(1)
    end
  end
end

describe "Qt::LockFile" do
  it "locks a file" do
    with_temp_dir do |root|
      path = ::File.join(root, "app.lock")
      lock = Qt::LockFile.new(path)
      lock.locked?.should be_false
      lock.try_lock(100).should be_true
      lock.locked?.should be_true
      ::File.exists?(path).should be_true

      other = Qt::LockFile.new(path)
      other.try_lock(10).should be_false
      other.error.should eq(Qt::LockFile::LockError::LockFailedError)

      lock.unlock
      lock.locked?.should be_false
      other.try_lock.should be_true
      other.unlock
    end
  end
end

describe "Qt::FileSystemWatcher" do
  it "watches paths" do
    with_temp_dir do |root|
      path = ::File.join(root, "watched.txt")
      ::File.write(path, "a")
      watcher = Qt::FileSystemWatcher.new
      watcher.add_path(path).should be_true
      watcher.add_paths([root]).to_a.should be_empty # All added
      watcher.files.to_a.should eq([path])
      watcher.directories.to_a.should eq([root])

      changed = [] of String
      watcher.on_file_changed { |name| changed << name }
      watcher.on_directory_changed { |name| changed << name }
      ::File.write(path, "bb")
      ::File.write(::File.join(root, "other.txt"), "")
      # The notifications arrive through the event loop, at the system's pace.
      loop = Qt::EventLoop.new
      elapsed = Qt::ElapsedTimer.new
      elapsed.start
      poll = Qt::Timer.new
      poll.on_timeout do
        loop.quit if (changed.includes?(path) && changed.includes?(root)) || elapsed.has_expired(5000)
      end
      poll.start(20)
      loop.exec
      changed.should contain(path)
      changed.should contain(root)

      watcher.remove_path(path).should be_true
      watcher.files.to_a.should be_empty
      watcher.remove_paths([root]).to_a.should be_empty
    end
  end
end

describe "Qt::DateTime" do
  it "wraps dates and times" do
    date = Qt::Date.new(2024, 2, 29)
    date.valid?.should be_true
    date.day_of_week.should eq(4) # Thursday
    date.add_days(1).to_string(Qt::DateFormat::ISODate).should eq("2024-03-01")
    Qt::Date.is_leap_year(2024).should be_true
    Qt::Date.from_string("2024-12-31", Qt::DateFormat::ISODate).day_of_year.should eq(366)
    Qt::Date.new(2023, 2, 29).valid?.should be_false

    time = Qt::Time.new(13, 45, 30, 250)
    time.to_string("HH:mm:ss.zzz").should eq("13:45:30.250")
    time.add_secs(30).minute.should eq(46)
    time.msecs_since_start_of_day.should eq(((13 * 60 + 45) * 60 + 30) * 1000 + 250)

    date_time = Qt::DateTime.new(date, time, Qt::TimeSpec::Utc)
    date_time.time_spec.should eq(Qt::TimeSpec::Utc)
    date_time.to_secs_since_epoch.should eq(1709214330)
    date_time.to_string(Qt::DateFormat::ISODate).should eq("2024-02-29T13:45:30Z")
    date_time.add_days(1).date.should eq(Qt::Date.new(2024, 3, 1))
    (date_time < date_time.add_m_secs(1)).should be_true
    Qt::DateTime.from_secs_since_epoch(0, Qt::TimeSpec::Utc).to_string("yyyy-MM-dd hh:mm").should eq("1970-01-01 00:00")
    Qt::DateTime.current_date_time_utc.secs_to(Qt::DateTime.current_date_time_utc).should eq(0)
  end
end
