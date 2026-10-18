# Support scripts

This directory hosts support (helper) scripts for Qt5.cr

## Contents

### `decide_binding_fast.cr`

Used to read (or generate) the "qt5.lock" file. This script is called from
`src/qt5/binding.cr`!

### `decide_binding_slow.cr`

Auto-detects which Qt5 version is available on the host system, and then chooses
the appropriate ready-built binding to use.  Used in tandem with
`decide_binding_fast.cr`:  If no "qt5.lock" file exists, it calls this script.
The reason for this split is that this code pulls in **bindgen** for the
detection part, making it quite slow to compile.

### `generate_bindings.cr`

(Re-)Generates the bindings for the configured Qt versions.  This script
automatically downloads and unpacks their sources from the internet, and then
generates all configured bindings using **bindgen**.

With `--system`, it instead generates the binding for the Qt5 installed on the
system, as found by `qmake`.  Set `QMAKE` to choose a specific installation.
This needs neither `curl` nor `tar`.

#### Dependencies

* `curl`
* `tar` with support for `tar.xz` archives
* **bindgen** and its dependencies (See `lib/bindgen/README.md`)
