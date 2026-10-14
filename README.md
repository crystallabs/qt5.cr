# Qt5 bindings for Crystal

Bindings for the Qt5 Framework using [bindgen2](https://github.com/docelic/bindgen2), a modernized
fork of [bindgen](https://github.com/Papierkorb/bindgen).

# Table of Contents

<!--ts-->
   * [Project Goals](#project-goals)
   * [Installation](#installation)
      * [Additional development dependencies](#additional-development-dependencies)
   * [User perspective](#user-perspective)
      * [Sample Crystal-Qt5 code](#sample-crystal-qt5-code)
   * [Developer perspective](#developer-perspective)
      * [Generating the bindings](#generating-the-bindings)
      * [Naming scheme](#naming-scheme)
      * [(Re)generating all Qt5 binding versions](#regenerating-all-qt5-binding-versions)
      * [(Re)generating a specific Qt5 binding version](#regenerating-a-specific-qt5-binding-version)
      * [Future things to do](#future-things-to-do)
   * [Platform Support](#platform-support)
   * [Contributing](#contributing)
      * [Contributors](#contributors)
   * [License](#license)
      * [A note on Qt's license](#a-note-on-qts-license)

<!-- Added by: docelic, at: Fri 29 May 2020 12:21:22 AM CEST -->

<!--te-->

# Project Goals

* **Just Works™** - Drop the dependency into a project, and use it
* Providing an API that feels native to Crystal
* Focus on the GUI components (i.e. `QtCore`, `QtGui`, `QtWidgets`)

# Installation

If you just want to develop a Crystal app which uses Qt5, use the `master-ready-to-use`
branch. It contains pre-built/pre-generated bindings for certain platform and Qt
combinations. If that branch contains the pre-generated bindings for your platform,
which you can verify in the
[subdirectory `ext/`](https://github.com/Papierkorb/qt5.cr/tree/master-ready-to-use/ext),
you won't need bindgen at all.

```yaml
dependencies:
  qt5:
    github: Papierkorb/qt5.cr
    branch: master-ready-to-use
```

If you want the bindings to be generated for the current system, or if you want
to generate bindings for new platform and Qt combinations, use the master
branch:

```yaml
dependencies:
  qt5:
    github: Papierkorb/qt5.cr
    branch: master
```

In any case, your users will be required to have the Qt5 libraries on their system
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

# Developer perspective

## Generating the bindings

If you want to work on `qt5.cr` itself or you want to generate bindings for new
versions, then as mentioned you need to use branch `master` and run the
generation yourself.

These steps can be followed from a project using `qt5.cr`, or from within
`qt5.cr` itself.  For the latter, you can just go to `lib/bindgen` and do `git
checkout master` instead of modifying `shard.yml`.

**Important**: For this you'll also have to meet the dependencies of bindgen.
See `lib/bindgen/README.md` and `lib/bindgen/clang/README.md`.

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

The `master-ready-to-use` branch contains a number of prebuilt bindings.
The following process was used to build them:

1. Cd into the `qt5.cr` directory, switch to the master branch
2. Edit `support/generate_bindings.cr` and enable all versions for which you want
to generate the bindings
3. Run `crystal support/generate_bindings.cr`
4. Commit the files in `ext/` to the `master-ready-to-use` branch

The build process will automatically download, unpack, build, and generate all
configured versions of Qt5.  It'll store the downloaded and unpacked Qt5 versions
to directory called `download_cache/`.
Subsequent invocations of that script will use these cached assets.

**The first run may take a long time, and each version of Qt5 will take up about
4GB of disk space**.

## (Re)generating a specific Qt5 binding version

1. Use the `master` branch of `qt5.cr` in your `shard.yml`
3. Decide which version of Qt to use, and build the scheme (See above)
4. Export the binding scheme: `export BINDING_PLATFORM=linux-gnu-x86_64-qt5.15`
5. If you're not using your system's Qt: `export QMAKE=/path/to/qmake`
6. Run bindgen as usual: `lib/bindgen/tool.sh qt.yml --stats`
7. Verify with `crystal spec`

## Future things to do

* Forwarding `qHash()` of wrapped types (to `Object#hash`)
* Integration with **LibEvent**: Right now, Qt blocks the whole thread.
* The rest of the billion Qt classes of interest
* Everything in the **to be done** category
* Integration for the `Qt Designer` UI designer
* Integration for `Qt Linguist`
  * Localization/Translation for your applications!
* UI test library, with adapter for `spec`
  * Also, actual tests - Let's catch whacko bugs right in the CI!
* Automated copy (and adaption) of the Qt documentation, for easy Crystal-specific docs
  * The Qt Docs license should allow this if done correctly

# Platform Support

| System            | Status           | Qt version | OOTB?   |
| ----------------- | ---------------- | ---------- | ------- |
| ArchLinux         | **Works always** | 5.12       | **YES** |
| Ubuntu 17.04      | **Works**        | 5.9        | **YES** |
| Ubuntu 16.04      | **Works**        | 5.5        | **YES** |
| MacOS             | Help wanted      | ?          | ?       |
| Windows           | Help wanted      | ?          | ?       |
| Other systems     | Help wanted      | ?          | ?       |

**Ready-to-use Qt versions:** 5.5 to 5.12

(This list needs updating)

# Contributing

1. Open a new issue on the project to discuss what you're going to do and possibly receive comments
3. Read bindgen's `STYLEGUIDE.md` for some tips
4. Then do the rest, PR and all.  You know the drill :)

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator

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
