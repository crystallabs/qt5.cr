/* Meta-objects for Crystal subclasses of QObject classes (SPEC.md §Q.4).  Used
 * by the `qt_meta_object` processor: `BgInherit_X` gets a `bgMeta` pointing
 * to a `BindgenQtMetaObject`, whose tables a Crystal class builds at runtime
 * through the `extern "C"` functions below, from the signals, slots and
 * properties it declares.  The layout is the one moc writes, by revision:
 * Qt 5.12+ (revision 8) and Qt 6.2+ (revisions 10 to 13).  Copy this file
 * next to `bindgen_helper.hpp` and include it after Qt's headers.
 */
#pragma once

#include <QtCore/QObject>
#include <QtCore/QMetaObject>
#include <QtCore/QMetaType>
#include <QtCore/QMetaMethod>
#include <QtCore/QString>
#include <QtCore/QByteArray>
#include <QtCore/QCoreApplication>
#include <cstring>
#include <new>
#include <string>
#include <vector>

#include "bindgen_helper.hpp"

#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
#include <QtCore/qtmocconstants.h>
#endif

namespace bindgen_qt {

// The uint layout, see `QMetaObjectPrivate` of qmetaobject_p.h, and
// `QtMocConstants` of Qt 6.9+.
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
const unsigned Revision = QtMocConstants::OutputRevision;
#elif QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
const unsigned Revision = 12;
#elif QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
const unsigned Revision = 11;
#elif QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
const unsigned Revision = 10; // Qt 6.2 to 6.4.  6.0 and 6.1 (revision 9) aren't supported.
#else
const unsigned Revision = 8; // Qt 5.12+
#endif

const unsigned HeaderSize = 14;
const unsigned IntsPerMethod = Revision >= 9 ? 6 : 5;
const unsigned IntsPerProperty = Revision >= 9 ? 5 : 3;

enum MethodFlags : unsigned {
  AccessPublic = 0x02,
  MethodMethod = 0x00,
  MethodSignal = 0x04,
  MethodSlot = 0x08,
};

enum PropertyFlags : unsigned {
  Readable = 0x00000001,
  Writable = 0x00000002,
  EnumOrFlag = 0x00000008,
  Designable = 0x00001000,
  Scriptable = 0x00004000,
  Stored = 0x00010000,
  Notify = 0x00400000,
};

enum EnumFlags : unsigned {
  EnumIsFlag = 0x1,
  EnumIsScoped = 0x2,
};

const unsigned IntsPerEnum = 5; // Name, alias, flags, count, data offset

const unsigned IsUnresolvedType = 0x80000000u;

// The QMetaType id of the type *name*, or 0 if unknown to Qt.
inline int type_id(const char *name) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  return QMetaType::fromName(name).id();
#else
  return QMetaType::type(name);
#endif
}

struct Method {
  unsigned flags;
  std::string name;
  std::string return_type;
  std::vector<std::string> types;
  std::vector<std::string> names;
};

struct Property {
  std::string name;
  std::string type;
  int notify; // The index of the notifying signal, or -1
  bool writable;
  bool is_enum; // An enum type: Qt looks its `QMetaEnum` up, and takes an int for it
};

struct ClassInfo {
  std::string key;
  std::string value;
};

/* An enumerator of the class: a Crystal enum a property, signal or slot of
 * the class uses, listed in the meta-object like a `Q_ENUM`, and registered
 * with `QMetaType` as `Class::Name` by `BindgenQtMetaObject::registerEnums`,
 * so `QObject::property` returns it, `setProperty` takes an int or a key,
 * and QML and queued connections carry it.  The values are ints.
 */
struct Enum {
  std::string name;
  bool is_flags;
  std::vector<std::string> keys;
  std::vector<int> values;
};

// The C++ type the registered enum types are modelled on: a scoped int enum.
enum class EnumModel : int {};

// *name* as Qt normalizes a type name: `QMap<QString,QVariant>`.
inline std::string normalized(const char *name) {
  QByteArray normal = QMetaObject::normalizedType(name);
  return std::string(normal.constData(), static_cast<size_t>(normal.size()));
}

} // namespace bindgen_qt

/* The call into Crystal of `qt_metacall`: the Crystal object, the
 * `QMetaObject::Call`, the index local to the class, and the arguments.
 */
typedef CrystalProc<void, void *, int, int, void **> BindgenQtMetacall;

/* One argument of a signal emitted from Crystal, see `bindgen_qt_activate`:
 * what *pointer* points to is passed as it is for kind 0, converted into a
 * `QString` from a `CrystalString` for kind 1, and into a `QByteArray` for
 * kind 2.
 */
struct BindgenQtArg {
  int kind;
  void *pointer;
};

/* The meta-object of a Crystal class, built once per class.  `superdata` is
 * the meta-object of the Crystal superclass, or the `staticMetaObject` of the
 * C++ class, set by the generated `SET_META` function.
 */
struct BindgenQtMetaObject {
  BindgenQtMetaObject(const char *class_name) : className(class_name) {
    std::memset(&meta, 0, sizeof(meta));
  }

  /* The `QMetaObject`.  Qt 6 reads the `QMetaType` of a property or a
   * parameter from the `metaTypes` table, which `finish` fills by name: a type
   * Qt didn't know then, like an enum no `QVariant` held yet, is looked up
   * again here, on the way to every property access or connection.
   */
  const QMetaObject *metaObject() {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    if (!unresolvedTypes.empty()) resolveMetaTypes();
#endif
    return &meta;
  }

  // Is *name* the class name of this meta-object, or of a Crystal parent?
  bool isClassName(const char *name) const {
    for (const BindgenQtMetaObject *m = this; m; m = m->parent) {
      if (m->className == name) return true;
    }
    return false;
  }

  int addMethod(unsigned flags, const char *name, const char *return_type, int argc, const char **types, const char **names) {
    bindgen_qt::Method method;
    method.flags = flags;
    method.name = name;
    method.return_type = bindgen_qt::normalized(return_type);
    for (int i = 0; i < argc; ++i) {
      method.types.push_back(bindgen_qt::normalized(types[i]));
      method.names.push_back(names[i]);
    }
    methods.push_back(method);
    return static_cast<int>(methods.size()) - 1;
  }

  int addProperty(const char *name, const char *type, int notify, bool writable, bool is_enum) {
    properties.push_back(bindgen_qt::Property{name, bindgen_qt::normalized(type), notify, writable, is_enum});
    return static_cast<int>(properties.size()) - 1;
  }

  // Adds the enumerator *name* with *count* *keys* and *values*, see `bindgen_qt::Enum`.
  int addEnum(const char *name, bool is_flags, int count, const char **keys, const int *values) {
    bindgen_qt::Enum e;
    e.name = name;
    e.is_flags = is_flags;
    for (int i = 0; i < count; ++i) {
      e.keys.push_back(keys[i]);
      e.values.push_back(values[i]);
    }
    enums.push_back(e);
    return static_cast<int>(enums.size()) - 1;
  }

  int addClassInfo(const char *key, const char *value) {
    classInfos.push_back(bindgen_qt::ClassInfo{key, value});
    return static_cast<int>(classInfos.size()) - 1;
  }

  // Builds the tables.  Call once, after the last `add*`, with the parent
  // meta-object of a Crystal superclass, or null.
  void finish(BindgenQtMetaObject *parent_meta, BindgenQtMetacall metacall_proc) {
    using namespace bindgen_qt;
    parent = parent_meta;
    crystalProc = metacall_proc;
    registerEnums(); // Before the type names are looked up

    // Signals first, as Qt expects them: stable partition.
    std::vector<Method> ordered;
    for (const Method &m : methods) if (m.flags & MethodSignal) ordered.push_back(m);
    signalCount = static_cast<int>(ordered.size());
    for (const Method &m : methods) if (!(m.flags & MethodSignal)) ordered.push_back(m);
    methods = ordered;

    // Strings: class name, then as referenced.
    stringIndex(className.c_str());
    const unsigned emptyString = stringIndex("");

    std::vector<unsigned> data(HeaderSize, 0);
    data[0] = Revision;
    data[1] = 0; // Class name

    // Class infos: key and value.
    data[2] = static_cast<unsigned>(classInfos.size());
    data[3] = classInfos.empty() ? 0 : HeaderSize;
    for (const ClassInfo &info : classInfos) {
      data.push_back(stringIndex(info.key.c_str()));
      data.push_back(stringIndex(info.value.c_str()));
    }

    // Methods, then their parameters.
    unsigned methodsOffset = static_cast<unsigned>(data.size());
    data[4] = static_cast<unsigned>(methods.size());
    data[5] = methods.empty() ? 0 : methodsOffset;
    unsigned parametersOffset = methodsOffset + static_cast<unsigned>(methods.size()) * IntsPerMethod;
    unsigned metaTypeOffset = static_cast<unsigned>(properties.size()) + (Revision >= 12 ? static_cast<unsigned>(enums.size()) : 0) + (Revision >= 10 ? 1 : 0);

    for (const Method &m : methods) {
      data.push_back(stringIndex(m.name.c_str()));
      data.push_back(static_cast<unsigned>(m.types.size()));
      data.push_back(parametersOffset);
      data.push_back(emptyString); // Tag
      data.push_back(m.flags);
      if (Revision >= 9) data.push_back(metaTypeOffset);
      parametersOffset += 1 + 2 * static_cast<unsigned>(m.types.size());
      metaTypeOffset += 1 + static_cast<unsigned>(m.types.size());
    }

    for (const Method &m : methods) {
      data.push_back(typeData(m.return_type.c_str()));
      for (const std::string &type : m.types) data.push_back(typeData(type.c_str()));
      for (const std::string &name : m.names) data.push_back(stringIndex(name.c_str()));
    }

    // Properties.
    data[6] = static_cast<unsigned>(properties.size());
    data[7] = properties.empty() ? 0 : static_cast<unsigned>(data.size());
    bool anyNotify = false;
    for (const Property &p : properties) {
      unsigned flags = Readable | Designable | Scriptable | Stored;
      if (p.writable) flags |= Writable;
      if (p.is_enum) flags |= EnumOrFlag;
      if (p.notify >= 0) { flags |= Notify; anyNotify = true; }
      data.push_back(stringIndex(p.name.c_str()));
      data.push_back(typeData(p.type.c_str()));
      data.push_back(flags);
      if (Revision >= 9) {
        data.push_back(p.notify >= 0 ? static_cast<unsigned>(p.notify) : 0);
        data.push_back(0); // Revision
      }
    }
    if (Revision < 9 && anyNotify) {
      for (const Property &p : properties) data.push_back(p.notify >= 0 ? static_cast<unsigned>(p.notify) : 0);
    }

    // Enumerators: name, alias, flags, count, data offset; then the key and
    // value pairs.  Crystal enums are scoped.
    data[8] = static_cast<unsigned>(enums.size());
    data[9] = enums.empty() ? 0 : static_cast<unsigned>(data.size());
    unsigned enumDataOffset = static_cast<unsigned>(data.size()) + static_cast<unsigned>(enums.size()) * IntsPerEnum;
    for (const Enum &e : enums) {
      const unsigned name = stringIndex(e.name.c_str());
      data.push_back(name);
      data.push_back(name); // Alias
      data.push_back(EnumIsScoped | (e.is_flags ? EnumIsFlag : 0));
      data.push_back(static_cast<unsigned>(e.keys.size()));
      data.push_back(enumDataOffset);
      enumDataOffset += 2 * static_cast<unsigned>(e.keys.size());
    }
    for (const Enum &e : enums) {
      for (size_t i = 0; i < e.keys.size(); ++i) {
        data.push_back(stringIndex(e.keys[i].c_str()));
        data.push_back(static_cast<unsigned>(e.values[i]));
      }
    }

    data[12] = 0; // Flags: property access through qt_metacall
    data[13] = static_cast<unsigned>(signalCount);
    data.push_back(0); // End of data

    this->data = data;
    buildStrings();
    buildMetaTypes();

    meta.d.superdata = nullptr;
    meta.d.data = this->data.data();
    meta.d.static_metacall = nullptr;
    meta.d.relatedMetaObjects = nullptr;
    meta.d.extradata = nullptr;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    meta.d.stringdata = stringData.data();
    meta.d.metaTypes = metaTypes.data();
#else
    meta.d.stringdata = byteArrayData;
#endif
    if (parent) setSuperdata(parent->metaObject());
  }

  // Sets the parent meta-object, once: the `SET_META` function of the C++
  // class gives its `staticMetaObject`, unless a Crystal superclass's was set
  // by `finish`.
  void setSuperdata(const QMetaObject *superdata) {
    if (meta.d.superdata) return;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    meta.d.superdata.direct = superdata;
#else
    meta.d.superdata = superdata;
#endif
  }

  /* The part of `qt_metacall` for this class, after the C++ base class
   * reduced *id* by its counts: a Crystal parent's part first, then this
   * class's methods and properties.  *object* is the C++ object, *crystal* its
   * Crystal object, or null once collected.  Returns the *id* reduced by this
   * class's counts, or a negative one once handled, like moc's code.
   */
  int metacall(QObject *object, void *crystal, QMetaObject::Call call, int id, void **argv) {
    if (parent) {
      id = parent->metacall(object, crystal, call, id, argv);
      if (id < 0) return id;
    }

    const int methodCount = static_cast<int>(methods.size());
    const int propertyCount = static_cast<int>(properties.size());

    switch (call) {
    case QMetaObject::InvokeMetaMethod:
      if (id < methodCount) {
        if (id < signalCount) {
          QMetaObject::activate(object, &meta, id, argv);
        } else if (crystal) {
          crystalProc(crystal, static_cast<int>(call), id, argv);
        }
      }
      id -= methodCount;
      break;
    case QMetaObject::RegisterMethodArgumentMetaType:
      if (id < methodCount) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        *reinterpret_cast<QMetaType *>(argv[0]) = QMetaType();
#else
        *reinterpret_cast<int *>(argv[0]) = -1;
#endif
      }
      id -= methodCount;
      break;
    case QMetaObject::ReadProperty:
    case QMetaObject::WriteProperty:
    case QMetaObject::ResetProperty:
      if (id < propertyCount && crystal) crystalProc(crystal, static_cast<int>(call), id, argv);
      id -= propertyCount;
      break;
    case QMetaObject::RegisterPropertyMetaType:
      if (id < propertyCount) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        *reinterpret_cast<QMetaType *>(argv[0]) = QMetaType();
#else
        *reinterpret_cast<int *>(argv[0]) = -1;
#endif
      }
      id -= propertyCount;
      break;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    case QMetaObject::BindableProperty:
      id -= propertyCount;
      break;
#else
    case QMetaObject::QueryPropertyDesignable:
    case QMetaObject::QueryPropertyScriptable:
    case QMetaObject::QueryPropertyStored:
    case QMetaObject::QueryPropertyEditable:
    case QMetaObject::QueryPropertyUser:
      id -= propertyCount;
      break;
#endif
    default:
      break;
    }

    return id;
  }

  QMetaObject meta;
  BindgenQtMetaObject *parent = nullptr;
  std::string className;
  std::vector<bindgen_qt::Method> methods;
  std::vector<bindgen_qt::Property> properties;
  std::vector<bindgen_qt::ClassInfo> classInfos;
  std::vector<bindgen_qt::Enum> enums;
  int signalCount = 0;
  BindgenQtMetacall crystalProc;

private:
  std::vector<std::string> strings;
  std::vector<unsigned> data;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  std::vector<unsigned> stringData; // (offset, size) pairs, then the characters
  std::vector<const QtPrivate::QMetaTypeInterface *> metaTypes;
  std::vector<std::pair<size_t, std::string>> unresolvedTypes; // Index into `metaTypes`, type name

  /* The `QMetaType` of an enumerator: an interface like `int`'s, flagged as
   * an enumeration, named `Class::Name`, whose meta-object is this one, so
   * `QMetaType::convert` finds the keys.  Qt keeps the pointer: never freed.
   */
  struct EnumType {
    QtPrivate::QMetaTypeInterface iface; // First: `enumMetaObject` casts back
    BindgenQtMetaObject *owner;
  };
  std::vector<EnumType *> enumTypes;

  static const QMetaObject *enumMetaObject(const QtPrivate::QMetaTypeInterface *iface) {
    return &reinterpret_cast<const EnumType *>(iface)->owner->meta;
  }

  void registerEnums() {
    const QtPrivate::QMetaTypeInterface &model = QtPrivate::QMetaTypeInterfaceWrapper<bindgen_qt::EnumModel>::metaType;
    for (const bindgen_qt::Enum &e : enums) {
      const char *name = qstrdup((className + "::" + e.name).c_str()); // Kept by Qt
      EnumType *type = new EnumType{
        {
          /*.revision=*/ model.revision,
          /*.alignment=*/ model.alignment,
          /*.size=*/ model.size,
          /*.flags=*/ model.flags,
          /*.typeId=*/ {},
          /*.metaObjectFn=*/ enumMetaObject,
          /*.name=*/ name,
          /*.defaultCtr=*/ model.defaultCtr,
          /*.copyCtr=*/ model.copyCtr,
          /*.moveCtr=*/ model.moveCtr,
          /*.dtor=*/ model.dtor,
          /*.equals=*/ model.equals,
          /*.lessThan=*/ model.lessThan,
          /*.debugStream=*/ model.debugStream,
          /*.dataStreamOut=*/ model.dataStreamOut,
          /*.dataStreamIn=*/ model.dataStreamIn,
          /*.legacyRegisterOp=*/ model.legacyRegisterOp,
        },
        this,
      };
      QMetaType(&type->iface).id(); // Registers it, or finds the type of the name
      enumTypes.push_back(type);
    }
  }

  // Looks the types `buildMetaTypes` didn't find up again.
  void resolveMetaTypes() {
    for (size_t i = 0; i < unresolvedTypes.size(); ) {
      const QtPrivate::QMetaTypeInterface *iface = interfaceOf(unresolvedTypes[i].second.c_str());
      if (iface) {
        metaTypes[unresolvedTypes[i].first] = iface;
        unresolvedTypes.erase(unresolvedTypes.begin() + static_cast<std::ptrdiff_t>(i));
      } else {
        ++i;
      }
    }
  }
#else
  std::vector<char> characters;
  QByteArrayData *byteArrayData = nullptr;

  // Registers the enumerators as int-sized enumeration types named
  // `Class::Name`, with this meta-object, so `QVariant::convert` finds the keys.
  void registerEnums() {
    typedef QtMetaTypePrivate::QMetaTypeFunctionHelper<int> Helper;
    for (const bindgen_qt::Enum &e : enums) {
      QByteArray name = QMetaObject::normalizedType((className + "::" + e.name).c_str());
      QMetaType::registerNormalizedType(name, Helper::Destruct, Helper::Construct, sizeof(int),
                                        QMetaType::TypeFlags(QMetaType::MovableType | QMetaType::IsEnumeration), &meta);
    }
  }
#endif

  unsigned stringIndex(const char *string) {
    for (size_t i = 0; i < strings.size(); ++i) {
      if (strings[i] == string) return static_cast<unsigned>(i);
    }
    strings.push_back(string);
    return static_cast<unsigned>(strings.size()) - 1;
  }

  // A type in the tables: Qt's id for a type it knows, else the name.
  unsigned typeData(const char *type) {
    int id = bindgen_qt::type_id(type);
    if (id > 0 && id < QMetaType::User) return static_cast<unsigned>(id);
    return bindgen_qt::IsUnresolvedType | stringIndex(type);
  }

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  void buildStrings() {
    const size_t pairs = 2 * strings.size();
    size_t total = 0;
    for (const std::string &s : strings) total += s.size() + 1;
    stringData.assign(pairs + (total + sizeof(unsigned) - 1) / sizeof(unsigned), 0);
    char *chars = reinterpret_cast<char *>(stringData.data() + pairs);
    unsigned offset = 0;
    for (size_t i = 0; i < strings.size(); ++i) {
      std::memcpy(chars + offset, strings[i].c_str(), strings[i].size() + 1);
      stringData[2 * i] = offset + static_cast<unsigned>(pairs * sizeof(unsigned));
      stringData[2 * i + 1] = static_cast<unsigned>(strings[i].size());
      offset += static_cast<unsigned>(strings[i].size()) + 1;
    }
  }

  static const QtPrivate::QMetaTypeInterface *interfaceOf(const char *type) {
    QMetaType mt = QMetaType::fromName(type);
    if (!mt.isValid()) {
      if (std::strcmp(type, "void") == 0 && bindgen_qt::Revision >= 11) return QMetaType::fromType<void>().iface();
      return nullptr;
    }
    return mt.iface();
  }

  // Properties, the enumerators (revision 12+), the class (void: unknown to
  // Qt), then the return type and the parameters of each method.  A type Qt
  // doesn't know yet is noted for `resolveMetaTypes`.
  void buildMetaTypes() {
    metaTypes.clear();
    unresolvedTypes.clear();
    for (const bindgen_qt::Property &p : properties) pushMetaType(p.type);
    if (bindgen_qt::Revision >= 12) {
      for (const EnumType *type : enumTypes) metaTypes.push_back(&type->iface);
    }
    if (bindgen_qt::Revision >= 10) metaTypes.push_back(QMetaType::fromType<void>().iface());
    for (const bindgen_qt::Method &m : methods) {
      pushMetaType(m.return_type);
      for (const std::string &type : m.types) pushMetaType(type);
    }
  }

  void pushMetaType(const std::string &type) {
    const QtPrivate::QMetaTypeInterface *iface = interfaceOf(type.c_str());
    if (!iface && type != "void") unresolvedTypes.push_back(std::make_pair(metaTypes.size(), type));
    metaTypes.push_back(iface);
  }
#else
  void buildStrings() {
    size_t total = 0;
    for (const std::string &s : strings) total += s.size() + 1;
    characters.assign(total, 0);
    delete[] byteArrayData;
    byteArrayData = new QByteArrayData[strings.size()];
    size_t offset = 0;
    for (size_t i = 0; i < strings.size(); ++i) {
      std::memcpy(characters.data() + offset, strings[i].c_str(), strings[i].size() + 1);
      qptrdiff relative = (characters.data() + offset) - reinterpret_cast<const char *>(&byteArrayData[i]);
      QByteArrayData d = Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(static_cast<int>(strings[i].size()), relative);
      std::memcpy(&byteArrayData[i], &d, sizeof(d)); // Not assignable: the static reference count
      offset += strings[i].size() + 1;
    }
  }

  void buildMetaTypes() { }
#endif
};

/* The receiver of a connection made by `bindgen_qt_connect`: one per
 * connection, with one slot, which forwards the arguments to the Crystal
 * `Proc`.  Its meta-object has no `static_metacall`, so Qt invokes the slot
 * through `qt_metacall`.  Lives in the thread creating it, the main thread, so
 * an automatic connection from another thread queues to it.
 */
class BindgenQtReceiver : public QObject {
public:
  BindgenQtReceiver(CrystalProc<void, void **> proc) : proc(proc) { }

  const QMetaObject *metaObject() const override { return staticMeta()->metaObject(); }

  void *qt_metacast(const char *name) override {
    if (name && std::strcmp(name, "BindgenQtReceiver") == 0) return this;
    return QObject::qt_metacast(name);
  }

  int qt_metacall(QMetaObject::Call call, int id, void **argv) override {
    id = QObject::qt_metacall(call, id, argv);
    if (id < 0) return id;
    if (call == QMetaObject::InvokeMetaMethod) {
      if (id == 0) proc(argv);
      --id;
    }
    return id;
  }

  // The index of the slot in the receiver's meta-object.
  static int slotIndex() { return staticMeta()->metaObject()->methodOffset(); }

private:
  CrystalProc<void, void **> proc;

  static BindgenQtMetaObject *staticMeta() {
    static BindgenQtMetaObject *meta = nullptr;
    if (!meta) {
      meta = new BindgenQtMetaObject("BindgenQtReceiver");
      meta->addMethod(bindgen_qt::MethodSlot | bindgen_qt::AccessPublic, "bgInvoke", "void", 0, nullptr, nullptr);
      meta->finish(nullptr, BindgenQtMetacall());
      meta->setSuperdata(&QObject::staticMetaObject);
    }
    return meta;
  }
};

// Weak, like those of `bindgen_helper.hpp`: defined in the one translation unit
// of the glue, and found by the binding's `fun`s.
#define BINDGEN_QT_C extern "C" __attribute__((weak))

BINDGEN_QT_C BindgenQtMetaObject *bindgen_qt_meta_new(const char *class_name) {
  return new BindgenQtMetaObject(class_name);
}

// *kind*: 0 a signal, 1 a slot, 2 an invokable method.
BINDGEN_QT_C int bindgen_qt_meta_add_method(BindgenQtMetaObject *meta, int kind, const char *name, const char *return_type, int argc, const char **types, const char **names) {
  unsigned flags = bindgen_qt::AccessPublic;
  flags |= kind == 0 ? bindgen_qt::MethodSignal : kind == 1 ? bindgen_qt::MethodSlot : bindgen_qt::MethodMethod;
  return meta->addMethod(flags, name, return_type, argc, types, names);
}

BINDGEN_QT_C int bindgen_qt_meta_add_property(BindgenQtMetaObject *meta, const char *name, const char *type, int notify, bool writable, bool is_enum) {
  return meta->addProperty(name, type, notify, writable, is_enum);
}

BINDGEN_QT_C int bindgen_qt_meta_add_class_info(BindgenQtMetaObject *meta, const char *key, const char *value) {
  return meta->addClassInfo(key, value);
}

// A Crystal enum of the class: its *name* without the scope, and *count* *keys* and *values*.
BINDGEN_QT_C int bindgen_qt_meta_add_enum(BindgenQtMetaObject *meta, const char *name, bool is_flags, int count, const char **keys, const int *values) {
  return meta->addEnum(name, is_flags, count, keys, values);
}

BINDGEN_QT_C void bindgen_qt_meta_finish(BindgenQtMetaObject *meta, BindgenQtMetaObject *parent, BindgenQtMetacall metacall) {
  meta->finish(parent, metacall);
}

BINDGEN_QT_C const QMetaObject *bindgen_qt_meta_object(BindgenQtMetaObject *meta) {
  return meta->metaObject();
}

// The index of the *local* signal of *meta* in the object's meta-object.
BINDGEN_QT_C int bindgen_qt_signal_index(BindgenQtMetaObject *meta, int local) {
  return meta->metaObject()->methodOffset() + local;
}

/* Emits the signal *local* of *meta* from *sender*, with the *count*
 * arguments, see `BindgenQtArg`.
 */
BINDGEN_QT_C void bindgen_qt_activate(QObject *sender, BindgenQtMetaObject *meta, int local, BindgenQtArg *args, int count) {
  std::vector<void *> argv(static_cast<size_t>(count) + 1, nullptr);
  std::vector<QString> strings;
  std::vector<QByteArray> bytes;
  strings.reserve(static_cast<size_t>(count));
  bytes.reserve(static_cast<size_t>(count));

  for (int i = 0; i < count; ++i) {
    switch (args[i].kind) {
    case 1: {
      const CrystalString *s = static_cast<const CrystalString *>(args[i].pointer);
      strings.push_back(QString::fromUtf8(s->ptr, static_cast<int>(s->size)));
      argv[i + 1] = &strings.back();
      break;
    }
    case 2: {
      const CrystalString *s = static_cast<const CrystalString *>(args[i].pointer);
      bytes.push_back(QByteArray(s->ptr, static_cast<int>(s->size)));
      argv[i + 1] = &bytes.back();
      break;
    }
    default:
      argv[i + 1] = args[i].pointer;
    }
  }

  QMetaObject::activate(sender, meta->metaObject(), local, argv.data());
}

/* Connects the signal at the *signal_index* of *sender*'s meta-object to the
 * *proc*, called with the argument vector, through a `BindgenQtReceiver`
 * deleted with the sender.
 */
BINDGEN_QT_C QMetaObject::Connection *bindgen_qt_connect(QObject *sender, int signal_index, int type, CrystalProc<void, void **> proc) {
  BindgenQtReceiver *receiver = new BindgenQtReceiver(proc);
  QObject::connect(sender, &QObject::destroyed, receiver, &QObject::deleteLater);
  QMetaObject::Connection connection = QMetaObject::connect(sender, signal_index, receiver, BindgenQtReceiver::slotIndex(), type, nullptr);
  return new (UseGC, bindgen_gc_finalizer<QMetaObject::Connection>()) QMetaObject::Connection(connection);
}

// A GC-allocated copy of *size* *bytes* as a `CrystalString`, for Crystal.
BINDGEN_QT_C CrystalString bindgen_qt_copy_bytes(const char *bytes, int size) {
  char *buffer = static_cast<char *>(GC_MALLOC_ATOMIC(size > 0 ? size : 1));
  if (size > 0) std::memcpy(buffer, bytes, static_cast<size_t>(size));
  return CrystalString{buffer, size};
}

// Reads the `QString` an argument vector slot points to.
BINDGEN_QT_C CrystalString bindgen_qt_string_at(void *slot) {
  QByteArray utf8 = static_cast<const QString *>(slot)->toUtf8();
  return bindgen_qt_copy_bytes(utf8.constData(), static_cast<int>(utf8.size()));
}

// Writes *string* into the `QString` an argument vector slot points to.
BINDGEN_QT_C void bindgen_qt_set_string(void *slot, CrystalString string) {
  *static_cast<QString *>(slot) = QString::fromUtf8(string.ptr, static_cast<int>(string.size));
}

BINDGEN_QT_C CrystalString bindgen_qt_bytes_at(void *slot) {
  const QByteArray &bytes = *static_cast<const QByteArray *>(slot);
  return bindgen_qt_copy_bytes(bytes.constData(), static_cast<int>(bytes.size()));
}

BINDGEN_QT_C void bindgen_qt_set_bytes(void *slot, CrystalString bytes) {
  *static_cast<QByteArray *>(slot) = QByteArray(bytes.ptr, static_cast<int>(bytes.size));
}

/* A value of a class passed by value, like a `QColor`, copied out of an
 * argument vector by `bindgen_qt_copy_value`: the `QMetaType` of the value,
 * for its destructor, is kept in front of it in the GC allocation.  The header
 * doesn't look like a `BindgenGCObject`, so the type discovery wraps the copy
 * anew.
 */
struct BindgenQtValueHeader {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  QMetaType type;
#else
  int type;
#endif
};

const size_t BindgenQtValueOffset = 16;
static_assert(sizeof(BindgenQtValueHeader) <= BindgenQtValueOffset, "the header must fit in front of the value");

static void GC_CALLBACK bindgen_qt_destruct_value(void *object, void *) {
  auto *header = static_cast<BindgenQtValueHeader *>(object);
  void *value = static_cast<char *>(object) + BindgenQtValueOffset;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  header->type.destruct(value);
#else
  QMetaType::destruct(header->type, value);
#endif
}

/* A copy of the value of *type*, a name `QMetaType` knows, at *source*, in a
 * GC allocation destructed by a finalizer, or null for an unknown type.  For
 * the slots and properties of Crystal classes taking a class by value.
 */
BINDGEN_QT_C void *bindgen_qt_copy_value(const char *type, const void *source) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  QMetaType mt = QMetaType::fromName(type);
  if (!mt.isValid()) return nullptr;
  const size_t size = static_cast<size_t>(mt.sizeOf());
#else
  int mt = QMetaType::type(type);
  if (mt == QMetaType::UnknownType) return nullptr;
  const size_t size = static_cast<size_t>(QMetaType::sizeOf(mt));
#endif

  void *memory = GC_MALLOC(BindgenQtValueOffset + size);
  new (memory) BindgenQtValueHeader{mt};
  void *value = static_cast<char *>(memory) + BindgenQtValueOffset;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  mt.construct(value, source);
#else
  QMetaType::construct(mt, value, source);
#endif
  GC_REGISTER_FINALIZER_IGNORE_SELF(memory, bindgen_qt_destruct_value, nullptr, nullptr, nullptr);
  return value;
}

/* Assigns the value of *type* at *source* to the one an argument vector slot
 * points to, the result of a slot or a property read, through the `QMetaType`.
 * False for a type Qt doesn't know.
 */
BINDGEN_QT_C bool bindgen_qt_set_value(void *slot, const char *type, const void *source) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
  QMetaType mt = QMetaType::fromName(type);
  if (!mt.isValid()) return false;
  mt.destruct(slot);
  mt.construct(slot, source);
#else
  int mt = QMetaType::type(type);
  if (mt == QMetaType::UnknownType) return false;
  QMetaType::destruct(mt, slot);
  QMetaType::construct(mt, slot, source);
#endif
  return true;
}

#undef BINDGEN_QT_C
