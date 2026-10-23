# Support scripts

This directory hosts support (helper) scripts for Qt5.cr

## Contents

### `decide_binding_fast.cr`

Used to read (or generate) the "qt5.lock" file. This script is called from
`src/qt5/binding.cr`!

Without a lock file, it chooses the binding by itself:

1. If `src/qt5/binding/` holds exactly one `binding_*.cr` and it is for the
   host platform, that one.
2. Else it finds `qmake` (`$QMAKE`, then `qmake-qt5`, then `qmake`, with
   `QT_SELECT=5`), asks it for `QT_VERSION`, requires Qt 5, and names the
   binding `{os}-{libc}-{arch}-qt{major.minor}` with the strings bindgen's
   `Bindgen::Variables.builtin` uses, e.g. `linux-gnu-x86_64-qt5.15`.
3. Only if that fails, it calls `decide_binding_slow.cr`.

The choice is saved in the lock file.  If the binding's static library
`ext/binding_*.a` doesn't exist yet, it builds it with `make`, using `qmake`'s
include directory, or the environment `decide_binding_slow.cr` sets up when
there's no `qmake`.

### `decide_binding_slow.cr`

Auto-detects which Qt5 version is available on the host system through
bindgen's path finding (`config/find_paths.yml`), and then chooses the
appropriate binding to use.  Used in tandem with `decide_binding_fast.cr`, as
its fallback, and by CI to name the binding it generates.  The reason for this
split is that this code pulls in **bindgen**, making it quite slow to compile.

### `generate_bindings.cr`

(Re-)Generates the bindings for the configured Qt versions.  This script
automatically downloads and unpacks their sources from the internet, and then
generates all configured bindings using **bindgen**.

With `--system`, it instead generates the binding for the Qt5 installed on the
system, as found by `qmake`.  Set `QMAKE` to choose a specific installation.
This needs neither `curl` nor `tar`.

The generated `src/qt5/binding/binding_*.cr` and `ext/qt_binding_*.cpp` of
the platforms CI builds are committed, see the README's "Generating the
bindings".  After regenerating them, commit both files of the platform.

#### Dependencies

* `curl`
* `tar` with support for `tar.xz` archives
* **bindgen** and its dependencies (See `lib/bindgen/README.md`)
