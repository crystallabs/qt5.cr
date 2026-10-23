# Qt5 bindings for Crystal

Bindings for the Qt5 Framework using [bindgen](https://github.com/crystallabs/bindgen).

# Table of Contents

<!--ts-->
   * [Project Goals](#project-goals)
   * [Installation](#installation)
      * [Additional development dependencies](#additional-development-dependencies)
   * [User perspective](#user-perspective)
      * [Sample Crystal-Qt5 code](#sample-crystal-qt5-code)
      * [Locale](#locale)
      * [String lists](#string-lists)
      * [Object lifetime](#object-lifetime)
      * [Threads](#threads)
      * [Null pointers](#null-pointers)
      * [Downcasts](#downcasts)
   * [Developer perspective](#developer-perspective)
      * [Generating the bindings](#generating-the-bindings)
      * [Deprecated Qt API](#deprecated-qt-api)
      * [Naming scheme](#naming-scheme)
      * [(Re)generating all Qt5 binding versions](#regenerating-all-qt5-binding-versions)
      * [(Re)generating the binding for the system's Qt5](#regenerating-the-binding-for-the-systems-qt5)
      * [(Re)generating a specific Qt5 binding version](#regenerating-a-specific-qt5-binding-version)
      * [Type rules](#type-rules)
      * [Future things to do](#future-things-to-do)
   * [Platform Support](#platform-support)
   * [Contributing](#contributing)
      * [Contributors](#contributors)
   * [License](#license)
      * [A note on Qt's license](#a-note-on-qts-license)
<!--te-->

# Project Goals

* **Just Works™** - Drop the dependency into a project, and use it
* Providing an API that feels native to Crystal
* Focus on the GUI components (i.e. `QtCore`, `QtGui`, `QtWidgets`)

# Installation

Add the shard to your `shard.yml`:

```yaml
dependencies:
  qt5:
    github: crystallabs/qt5.cr
```

Then generate the binding for the Qt5 installed on your system, see
[(Re)generating the binding for the system's Qt5](#regenerating-the-binding-for-the-systems-qt5).
This needs bindgen and its dependencies, listed below.

Your users will be required to have the Qt5 libraries on their system
because this project defaults to binding to Qt libraries dynamically. (See more
on this under License below.)

## Additional development dependencies

Using your system's package manager:

* **ArchLinux** `pacman -S qt5-base gc cmake llvm clang pcre2`
* **Debian/Ubuntu/Devuan** `apt-get install qtbase5-dev libgc-dev cmake llvm-dev clang libclang-dev libpcre2-dev libz-dev libstdc++-dev`

Bindgen needs LLVM and Clang 14 or newer, CMake 3.12 or newer and Crystal 1.8
or newer.

If linking Crystal programs fails with undefined references like
`__isoc23_strtol` from `libgc.a`, your Crystal package bundles a `libgc` built
for a newer glibc than your system has (e.g. recent Crystal on Debian 12).
Link against the system's `libgc` instead:

```sh
export CRYSTAL_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
```

# User perspective

## Sample Crystal-Qt5 code

Have a look in [samples/](https://github.com/Papierkorb/qt5.cr/tree/master/samples)!

A short **Hello World** snippet looks like this:

```crystal
require "qt5"

qApp = Qt::Application.new

label = Qt::Label.new "Hello from Crystal/Qt!"
label.show

Qt::Application.exec
```

![hello-qt](https://raw.githubusercontent.com/Papierkorb/qt5.cr/master/images/hello-qt.png)

## Locale

By default Qt sets the locale to the system locale when an application
class (like `Qt::Application`) is instantiated. However, this causes
stdlib Crystal functions like `to_f` to behave unexpectedly, e.g.,
using a different character as decimal separator (also see the discussion
of this [PR](https://github.com/Papierkorb/qt5.cr/pull/51)).
Therefore, in contrast to the behaviour of the C++ classes of Qt,
`qt5.cr` resets the numeric locale to "C" after creating an
application class instance (this follows an [advice from Qt
itself](https://doc.qt.io/qt-5/qcoreapplication.html#locale-settings)).

## String lists

`QStringList` is a `QList<QString>`: methods taking one accept any
`Enumerable(String)`, and methods returning one return a `Qt::StringList`,
which is an `Indexable(String)` with Qt's own methods: `#filter`,
`#replace_in_strings`, `#remove_duplicates`, `#sort(cs)`, `#join`, `#contains`,
`#index_of`, `#remove_all`, `#take_first` and the rest of `QList`.

```crystal
combo_box.add_items(["one", "two"])
names = Qt::Dir.new(".").entry_list(["*.cr"], Qt::Dir::Filters::Files)
names.sort(Qt::CaseSensitivity::CaseInsensitive) # In place
names.filter(".cr").to_a
```

`#sort(cs = CaseSensitive)` sorts in place.  `#join` is `Enumerable`'s, which
Crystal finds before the superclass holding Qt's, with the same result.
Likewise, `Qt::Polygon` is an `Indexable(Qt::Point)`.

## Object lifetime

Objects created from Crystal are collected by the GC once Crystal no longer
refers to them.  Qt's references, like a layout's to its widgets, are invisible
to the GC.  So the methods by which Qt takes ownership of an object or keeps a
pointer to it, like `Qt::Layout#add_widget`, `Qt::ListWidget#add_item`,
`Qt::MainWindow#central_widget=`, `Qt::AbstractItemView#model=` or
`Qt::PushButton#menu=`, keep their arguments alive:

```crystal
layout.add_widget Qt::Label.new("Stays alive")
view.model = Qt::StandardItemModel.new # Stays alive too
button.menu = Qt::Menu.new             # And so does this
```

Objects created from Crystal are kept alive until Qt deletes them, like a
parent deletes its children, or until passed to `Qt::BindgenHelper.release`,
e.g. after taking a widget out again without deleting it.  An object Qt created
itself, which Crystal only wraps, is kept until released:

```crystal
layout.remove_widget(label)
Qt::BindgenHelper.release(label)
```

The methods are configured in `config/keep_alive.yml`.  Giving an object a
parent by its constructor or `#parent=` doesn't keep it alive: keep a
reference to it, or add it by one of these methods.

## Threads

`Qt::Thread`, `Qt::ThreadPool` and the locks are bound, but **a Qt thread
must not call into Crystal**: the Crystal runtime and its GC only know the
threads they start, so a Crystal method run from a Qt thread corrupts the
program.  Deleting a wrapped object counts, as its destructor calls into
Crystal to release it from `keep_alive`.  A thread started from Crystal runs Qt
code only, like the event loop `QThread::run` starts by default, and the queued
signals it emits are delivered in the main thread:

```crystal
thread = Qt::Thread.new
thread.on_finished { puts "done" } # Called from the main event loop
thread.start
thread.quit
thread.wait
```

`QThread` and `QRunnable` are the one place a Crystal override of a virtual
method is unsupported: they get no C++ subclass, so a Crystal `run` is never
called (and a Crystal `Qt::Runnable` subclass can't be instantiated).  Use
Crystal's own `Thread` or fibers for Crystal work.  The locks exclude Qt
threads from Qt data: `mutex.lock`, `semaphore.acquire(2)`,
`condition.wait(mutex, Qt::DeadlineTimer.new(100))`.

## Null pointers

A method returning a pointer to a Qt object returns `nil` when the pointer is
null, so its result is a union with `Nil`: `Qt::Widget#parent_widget` is a
`Qt::Widget?`, `Qt::ListWidget#item` a `Qt::ListWidgetItem?`, and so are
`Qt::AbstractItemView#model`, `Qt::StandardItem#child` or
`Qt::AnimationGroup#take_animation`.  Check the result, or unwrap it with
`not_nil!` where it can't be null, like the menu bar a `Qt::MainWindow` creates
on demand and the menu added to it:

```crystal
if item = list.item(row)
  puts item.text
end

menu = window.menu_bar.not_nil!.add_menu("File").not_nil!
```

Only method results are nilable.  A method returning a reference, like
`Qt::Widget#font`, always returns an object, as does a cast like
`Qt::Widget#as_paint_device`.  The elements of a returned list, like
`Qt::StandardItemModel#take_row`, are the objects themselves, and so is the
argument a signal or an overridden virtual method receives: a block of
`Qt::StandardItemModel#on_item_changed` gets a `Qt::StandardItem`, and an
override of `Qt::Widget#mouse_press_event` takes a `Qt::MouseEvent`, as
declared (see `samples/virtual_override.cr`).  This is bindgen's
`nilable_results` option, set in `qt.yml`.

## Downcasts

A wrapper is of the class a method declares, so `Qt::Layout#item_at` returns a
`Qt::LayoutItem` and `Qt::Object#children` holds `Qt::Object`s.  `#to?`
casts to a subclass, returning `nil` when the object isn't one:

```crystal
if button = widget.to?(Qt::PushButton)
  button.flat = true
end
```

A cast to an abstract class, like `Qt::AbstractButton`, wraps the object in
its `Impl` class.  The cast is C++'s `dynamic_cast`, so the binding is built
with RTTI (`ext/Makefile`), as Qt itself is.

# Developer perspective

## Generating the bindings

If you want to work on `qt5.cr` itself or you want to generate bindings for new
versions, run the generation yourself as described below.

These steps can be followed from a project using `qt5.cr` (in `lib/qt5`), or
from within `qt5.cr` itself.

**Important**: For this you'll also have to meet the dependencies of bindgen.
See `lib/bindgen/README.md` and `lib/bindgen/clang/README.md`.

## Deprecated Qt API

The bindings don't wrap deprecated Qt API.  The headers are parsed and the C++
wrappers built as C++17 with `QT_DISABLE_DEPRECATED_BEFORE=0x050F00` (see
`qt.yml` and `ext/Makefile`), which hides the declarations Qt deprecated up to
5.15.  What Qt deprecated later is declared `[[deprecated]]`, which bindgen's
`ignore_deprecated: true` drops overload by overload, so a non-deprecated
overload like `QSpinBox::valueChanged(int)` stays.

Building the bindings should thus print no `-Wdeprecated-declarations`
warnings, and CI fails if it does.

## Naming scheme

As `qt5.cr` supports many different versions of Qt on different platforms,
generated bindings follow a naming scheme.  The scheme contains 4 components
as follows:

`KERNEL - LIB_C - ARCH - qtVERSION`, e.g. `linux-gnu-x86_64-qt5.13`

Where:

* `KERNEL` is the OS kernel, e.g. `linux`, `darwin`, `windows`
* `LIB_C` is the lib C name, e.g. `gnu`, `musl`, `win32`
* `ARCH` is the architecture, e.g. `i686`, `x86_64`, `arm`
* `VERSION` is the Qt version, e.g. `5.9`, `5.12`, `5.15`

The naming scheme is not strictly enforced.  However, it should always end with
`-qtVERSION`!

## (Re)generating all Qt5 binding versions

To generate bindings for several Qt5 versions from their sources:

1. Cd into the `qt5.cr` directory
2. Edit `support/generate_bindings.cr` and enable all versions for which you want
to generate the bindings
3. Run `crystal support/generate_bindings.cr`

The build process will automatically download, unpack, build, and generate all
configured versions of Qt5.  It'll store the downloaded and unpacked Qt5 versions
to directory called `download_cache/`.
Subsequent invocations of that script will use these cached assets.

**The first run may take a long time, and each version of Qt5 will take up about
4GB of disk space**.

## (Re)generating the binding for the system's Qt5

To generate the binding for the Qt5 installed on your system, without
downloading Qt sources, run from the `qt5.cr` directory:

```sh
crystal support/generate_bindings.cr -- --system
```

It asks `qmake` (`qmake-qt5` or `qmake`, or `$QMAKE` if set) where Qt is
installed and which version it is, and names the binding after the host, e.g.
`linux-gnu-x86_64-qt5.15`.

## (Re)generating a specific Qt5 binding version

1. Decide which version of Qt to use, and build the scheme (See above)
2. Export the binding scheme: `export BINDING_PLATFORM=linux-gnu-x86_64-qt5.15`
3. If you're not using your system's Qt: `export QMAKE=/path/to/qmake`
4. Run bindgen as usual: `lib/bindgen/tool.sh qt.yml --stats`
5. Verify with `crystal spec`

## Type rules

`config/types.yml` holds the rules Qt needs beyond bindgen's built-in types,
see the comments there:

* `QStringList` and `QVariantList` are aliases of `QList<QString>` and
  `QList<QVariant>`, so methods take any `Enumerable(String)`:
  `combo_box.add_items(["a", "b"])`.  `QList<QString>` and
  `QListSpecialMethods<QString>`, which holds the `QStringList` methods, are
  listed as classes, so the wrapper `Qt::StringList` has those methods.  The
  overloads taking `QStringView`, `QLatin1String` or the old `QRegExp` are
  dropped, as the Crystal `String` maps to `QString` and `QRegularExpression`
  is wrapped.
* `QVariant` maps to `Qt::Variant`, which exchanges the types Qt knows in
  their native form, so Qt can display, sort and store them: `Nil`, `Bool`,
  `Int32`, `UInt32`, `Int64`, `UInt64`, `Float32`, `Float64`, `Char`, `String`,
  `Bytes`, `Array(String)` (`QStringList`), `Point`, `PointF`, `Size`, `SizeF`,
  `Rect` and `RectF`.  Any other Crystal value is wrapped as is and comes back
  unchanged; a `QVariant` of another Qt type unpacks as unknown (`#to?`
  returns `nil`).  See `Qt::Variant`.
* `QByteArray` maps to `Bytes`, copied in both directions like `QString`:
  `String.new(Qt::Url.to_percent_encoding(text))`, `mime_data.set_data(type,
  bytes)`.  `QList<QByteArray>` is an `Enumerable(Bytes)`.
* `QFile`, `QDir`, `QTime` and the like keep their names, so `Qt::File`,
  `Qt::Dir` and `Qt::Time` shadow the standard library's inside `module Qt`:
  write `::File` and `::Time::Span` there.
* The typedefs of lists, like `QFileInfoList` and `QModelIndexList`, are
  aliases of their `QList`, so `dir.entry_info_list` is an
  `Enumerable(Qt::FileInfo)`; `QItemSelection` derives from one, so
  `Qt::ItemSelection` is an `Indexable(Qt::ItemSelectionRange)`.
* A Crystal model only implements what its C++ counterpart would:
  `row_count(parent)` and `data(index, role)` for a `Qt::AbstractListModel`.
  bindgen splits the overloads a default argument can't express off the
  pure virtuals, calling C++ with the default.
* `QAbstractTextDocumentLayout::PaintContext` and `Selection`,
  `QTextLayout::FormatRange`, bare structs of Qt classes, are wrapped as
  classes with property methods: `Qt::TextDocumentLayoutPaintContext`,
  `Qt::TextLayoutFormatRange`.
* `QTextFrame::iterator` and `QTextBlock::iterator` are Crystal `Iterator`s
  (`src/qt5/text_iterators.cr`): `frame.begin.each { |frame_or_block| }`,
  `block.begin.map(&.text)`.  `QFontDatabase` is an instance in Qt 5:
  `Qt::FontDatabase.new.families`.
* `Qt::TreeWidgetItemIterator` is an `Iterator(TreeWidgetItem)`:
  `Qt::TreeWidgetItemIterator.new(tree).each { |item| ... }`.
* `QHeaderView`'s protected `initialize()` is `#cpp_initialize`, as Crystal
  reserves the name for constructors.
* `QValidator::validate` and `fixup` take the input by non-const reference,
  which bindgen can't pass a `String` (a `QString` by value) by, so
  `ext/validator_helper.hpp` calls them on a copy: `validator.validate("42")`
  returns the `Validator::State`, `#fixup` the fixed string.  Validators can't
  be written in Crystal: as the pure virtual `validate` is dropped, bindgen
  skips the C++ subclass (a warning, shown by `tool.sh --debug`).
* The `QStyle` enum constants drop their prefixes:
  `Style::PixelMetric::ButtonMargin`, `Style::State::Enabled`.
* `QGraphicsWidget` derives from `QGraphicsObject` and `QGraphicsLayoutItem`:
  the wrapper has the layout item methods, and `#as_graphics_layout_item`
  casts it for `GraphicsLinearLayout#add_item` and friends.
* A `QList<QPair<...>>`, like `GraphicsItemAnimation#pos_list`, is an
  `Enumerable` of tuples, through the `QPair` container rule.
* `QMap` and `QHash` are associative containers, exchanged as a `Hash`-like
  `Enumerable({K, V})` with `#[]`, `#[]?`, `#has_key?` and `#keys`:
  `StandardItemModel#item_data(index)` is one of `Int32` to `Variant`,
  `AbstractItemModel#role_names` of `Int32` to `Bytes`,
  `CalendarWidget#date_text_format` of `Date` to `TextCharFormat`, and the
  setters take a `Hash`: `model.set_item_data(index, {role => Qt.variant(x)})`.
  `QVariantMap` and `QVariantHash` (`JsonObject#to_variant_map`) are
  `Hash(String, Variant)`-like.
* `QVector2D`, `QVector3D`, `QVector4D`, `QQuaternion`, `QRgba64` and
  `QPainterPath::Element` are copied structures passed by value, like
  `QPoint`, with property methods for their public fields: `element.x`.
* A `bool *ok = nullptr` argument is `ok : Bool*? = nil`:
  `locale.to_int("42")`, or `transform.inverted(pointerof(invertible))` to
  learn the outcome.
* `QMatrix3x3` (a `QGenericMatrix` instantiation) has no mapping, which drops
  `Matrix4x4#normal_matrix` and `Quaternion#to_rotation_matrix`.
  `QGradientStops` is a `QVector<QPair<qreal, QColor>>`, so `Gradient#stops`
  is an `Enumerable({Float64, Color})` and the setter takes an array of tuples.
* The QXmlStream classes return names, values and text as `QStringRef`, which
  has no mapping (a reference into a temporary `QString` would dangle), so
  `src/qt5/xml_stream.cr` wraps the helpers of `ext/xml_helper.hpp`:
  `reader.name`, `attribute.value`, `reader.attributes.value("id")`.
  `QXmlStreamAttributes` is a `QVector<QXmlStreamAttribute>`, so
  `reader.attributes.map(&.name)` works.
* `QDataStream` reads `QString` and `QByteArray` through free `operator>>`,
  which take them by non-const reference: `src/qt5/data_stream.cr` adds
  `stream.read(String)`, `stream.read(Bytes)` and `stream.read(Int32)` over
  the wrapped `>>(Int32*)`; `stream << "text"` and `<< bytes` are wrapped as
  is.  The `>>` of a copied structure (`QPoint &`) is dropped like
  `QValidator::validate` above.
* `QTouchEvent::TouchPoint` is `Qt::TouchPoint`; `QPointingDeviceUniqueId`
  is a copied structure: `PointingDeviceUniqueId.from_numeric_id(42)`.
* `QJsonObject#[]` returns a `JsonValue` copy; `QJsonArray#[]` a
  `JsonValueRef`, whose `#assign!` writes through.  `QJsonObject#insert`
  returns a `JsonObjectIterator`.  Likewise `CborMap#insert` returns a
  `CborMapIterator` with `#key` and `#value` (a `CborValueRef`); the pair
  of references the iterator dereferences to isn't default constructible,
  which a pair container needs, so it is ignored.  `QCborTag` and
  `QCborNegativeInteger`, `enum class`es without enumerators, are `UInt64`:
  `CborValue.new(Qt::CborKnownTags::Url, value).tag` is `32`, and
  `CborStreamWriter#append(UInt64)` appends a tag, so append integers as
  `Int64`.  `CborValue.new(Qt::CborValue::Type::Null)` replaces the `nullptr`
  constructor.  `QCborStreamReader::readString` returns a `StringResult<T>`
  bindgen doesn't instantiate, so `ext/cbor_helper.hpp` adds
  `reader.read_all_string` and `#read_all_byte_array` (Qt 6's names), and
  `CborStreamWriter#append(String)` over the unwrapped `QStringView` overload.
  Qt 5 declares the `QDataStream` operators of `QCborSimpleType` without
  exporting them, so the helper defines them for the binding to link.
* `QStyleOptionTabV4` is the one V-suffixed style option still a class in
  Qt 5 (`option.tab_index`); the others are deprecated typedefs of the
  current classes.  `StyleHintReturnMask#region` and
  `StyleHintReturnVariant#variant` are properties.
* A Crystal `Qt::IconEngine` subclass implements `paint` and `clone`
  (see `spec/qt/providers_spec.cr`).  `clone` is declared `IconEngine?`, as
  every pointer result is; an override returning `nil` passes a null pointer
  to C++, as for any Crystal override of a virtual method returning a pointer.
* A Crystal creator derives from the abstract `Qt::ItemEditorCreatorBase`
  (its implicit default constructor is wrapped), implementing
  `create_widget(parent)` and `value_property_name` (`Bytes`), and registers
  with `ItemEditorFactory#register_editor(Qt::MetaType::Type::Int.to_i, creator)`.
  `QItemEditorCreator<T>` and `QStandardItemEditorCreator<T>` are templates
  and aren't bound.
* `QMutex` is `Qt::Mutex`, deriving from `QBasicMutex`, which is listed so
  the methods are inherited.  `QRecursiveMutex` derives privately from
  `QMutex` in Qt 5 and re-exports `lock`, `tryLock` and `unlock` with
  using-declarations, which are wrapped.  `#try_lock(timeout = 0)` is
  `tryLock(int)`: bindgen drops the std-style `try_lock()` and `try_acquire()`
  aliases, whose Crystal signatures equal or overlap the originals';
  `try_lock_for` and friends are
  templates.  `QException`, which only serves throwing across QtConcurrent
  threads, isn't bound: it would shadow `::Exception` inside the module.
* The meta-object system exchanges names as `const char *`, an `UInt8*`:
  `String.new(meta_object.class_name)`,
  `meta_object.index_of_property("text".to_unsafe)`.  `Qt::Widget.
  static_meta_object` is a copy of the class's `QMetaObject`, which the
  pointer comparison of `MetaObject#inherits` doesn't match: pass an
  instance's `meta_object`.  `QMetaObject::invokeMethod` and
  `QMetaMethod::invoke` take `QGenericArgument`s (type name and `void *`
  pairs) or are templates, so they are dropped;
  `Qt::MetaObject.invoke_method(object, "click")` (`ext/meta_helper.hpp`)
  invokes a method without arguments.  `MetaType::Type` keeps Qt's constant
  names, `MetaType::Type::QString`.  `QMetaObject`'s public `d`, an
  anonymous struct of moc-generated tables, gets no property method, as the
  struct has no Crystal wrapper.
* `QTextCodec` (Qt 5 only) is `Qt::TextCodec`: `TextStream#codec=` takes one,
  `TextCodec.codec_for_name("UTF-8".to_slice)` is nilable.
  `Qt::TextEncoder` and `Qt::TextDecoder` keep the conversion state between
  calls; the codec's own stateful conversions (`ConverterState`) aren't
  wrapped.
* Types without a mapping yet, like `std::function` callbacks or `QSet`,
  are ignored, which drops the methods using them.

## Future things to do

* Forwarding `qHash()` of wrapped types (to `Object#hash`)
* Integration with **LibEvent**: Right now, Qt blocks the whole thread.
* The rest of the billion Qt classes of interest
* Integration for the `Qt Designer` UI designer
* Integration for `Qt Linguist`
  * Localization/Translation for your applications!
* UI test library, with adapter for `spec`
* Automated copy (and adaption) of the Qt documentation, for easy Crystal-specific docs
  * The Qt Docs license should allow this if done correctly

# Platform Support

| System                   | Status           | Qt version | Notes                       |
| ------------------------ | ---------------- | ---------- | --------------------------- |
| Ubuntu 24.04             | **Works**        | 5.15       | CI, with LLVM 14 and 18     |
| macOS (Homebrew `qt@5`)  | **Works**        | 5.15       |                             |
| ArchLinux                | Should work      | 5.15       | Help wanted                 |
| Windows                  | Untested         | ?          | Help wanted                 |

The bindings target Qt 5.15 and hide the API it deprecates (see
[Deprecated Qt API](#deprecated-qt-api)), so older Qt 5 versions are untested.

# Contributing

1. Open a new issue on the project to discuss what you're going to do and possibly receive comments
2. Read bindgen's `STYLEGUIDE.md` for some tips
3. Then do the rest, PR and all.  You know the drill :)

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator
- [docelic](https://github.com/docelic) Davor Ocelic - maintainer

# License

The Qt bindings, including the generated and manually-written parts, are subject
to the MPL-2 license.  You can find a copy attached of the full license text in
the `LICENSE` file.

This project claims no copyright on the `Qt framework` or of any of its
trademarks, source, or any other assets.

## A note on Qt's license

A common misconception is that you have to pay for Qt to use it in closed-source
applications.

This project assumes you'll link to Qt dynamically.  In this case, you can use
**Qt free of charge** including for **closed-source, commercial applications**
under the terms of the **LGPL**.

You can build closed-source applications using Crystal, this shard, and Qt
**for free**.

**Note**: This section is to combat this misconception, the authors of `qt5.cr`
are in no way responsible to check if the same terms apply **in your jurisdiction**.
