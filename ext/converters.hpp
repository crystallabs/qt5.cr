#include <gc/gc.h> // Boehm GC
#include <cstring>
#include <QtCore/qbytearray.h>
#include <QtCore/qchar.h>
#include <QtCore/qmetatype.h>
#include <QtCore/qpoint.h>
#include <QtCore/qrect.h>
#include <QtCore/qsize.h>
#include <QtCore/qstring.h>
#include <QtCore/qstringlist.h>
#include <QtCore/qvariant.h>

#include "bindgen_helper.hpp"
#include "bindgen_qt_meta.hpp" // Meta-objects of Crystal subclasses, bindgen's asset

// Converts a QString into a CrystalString, whose definition is mirrored in
// Crystal and is then turned into a Crystal `String`.
static CrystalString qstring_to_crystal(const QString &str) {
  // FIXME: This is horrible.
  QByteArray utf8 = str.toUtf8();
  int size = utf8.size();

  char *buffer = static_cast<char *>(GC_MALLOC_ATOMIC(size));
  memcpy(buffer, utf8.constData(), size);

  return CrystalString{ buffer, size };
}

// Holders of a QString built from a Crystal String, converting to a view of
// it: a holder is a temporary of the call it's passed to, so the view lives
// for the call.  The conversions of QStringView, QStringRef and QLatin1String
// arguments, see config/types.yml.  Each converts to one view type only, so
// overloads taking either stay unambiguous.
struct qt5cr_string_view {
  QString string;
  explicit qt5cr_string_view(CrystalString str) : string(QString::fromUtf8(str.ptr, str.size)) { }
  operator QStringView() const { return QStringView(string); }
};

struct qt5cr_string_ref {
  QString string;
  explicit qt5cr_string_ref(CrystalString str) : string(QString::fromUtf8(str.ptr, str.size)) { }
  operator QStringRef() const { return QStringRef(&string); }
};

struct qt5cr_latin1_string {
  QByteArray latin1;
  explicit qt5cr_latin1_string(CrystalString str) : latin1(QString::fromUtf8(str.ptr, str.size).toLatin1()) { }
  operator QLatin1String() const { return QLatin1String(latin1.constData(), latin1.size()); }
};

// Converts a QByteArray into a CrystalString of its raw bytes, which Crystal
// turns into a `Bytes`.  The copy is GC-allocated, so the `Bytes` uses it
// directly.
static CrystalString qbytearray_to_crystal(const QByteArray &bytes) {
  int size = bytes.size();
  char *buffer = static_cast<char *>(GC_MALLOC_ATOMIC(size));
  memcpy(buffer, bytes.constData(), size);

  return CrystalString{ buffer, size };
}

// Wraps run-time information on a Crystal type.  Basically a C++ representation
// to store Crystals tagged unions of any type of up to 16KiB in size.
// Used to marshal to and from QVariant.
//
// Values of the Qt types Qt itself knows how to display, sort or store are
// exchanged in their native form instead, marked by a negative `typeId` (a
// `Tag`): Crystal tags them in `Qt::Variant#to_unsafe`, and
// `crystal_to_qvariant` turns them into the native QVariant.  The other way,
// `qvariant_to_crystal` tags the native Qt values, and `Qt::Variant.new`
// repacks them as the Crystal value.  Any other Crystal value is wrapped as
// is, as a QVariant of the `CrystalVariant` metatype.
//
// ATTENTION: This structure, including its constants, are mirrored in Crystal.
//            Changes here must be reflected in Crystal, else happy debug times ensue!
struct CrystalVariant {
  // Size of the largest inline-able value.  Must be at least the size of a
  // pointer.
  static constexpr int INLINE_SIZE = 16; // 2 * sizeof(void*);

  // Crystal type id of `nil`.  Also used for an invalid or null QVariant.
  static constexpr int CRYSTAL_NIL_ID = 0;

  // Tags, in `typeId`, of values exchanged in their native Qt form.  Negative,
  // as Crystal type ids are positive.  Mirrored in Crystal as `Qt::Variant::Tag`.
  enum Tag : int32_t {
    TAG_UNKNOWN = -1,      // A Qt type without a Crystal mapping.  No data.
    TAG_BOOL = -2,         // bool, in bytes[0]
    TAG_INT32 = -3,        // int, inline
    TAG_UINT32 = -4,       // unsigned int, inline
    TAG_INT64 = -5,        // qlonglong, inline
    TAG_UINT64 = -6,       // qulonglong, inline
    TAG_FLOAT32 = -7,      // float, inline
    TAG_FLOAT64 = -8,      // double, inline
    TAG_CHAR = -9,         // QChar, as a UTF-32 code point in a uint32_t, inline
    TAG_STRING = -10,      // QString, as a CrystalString of UTF-8, inline
    TAG_BYTES = -11,       // QByteArray, as a CrystalString of the raw bytes, inline
    TAG_STRING_LIST = -12, // QStringList, `reference` points to a GC-allocated QList<QString>
    TAG_POINT = -13,       // QPoint, inline
    TAG_POINTF = -14,      // QPointF, inline
    TAG_SIZE = -15,        // QSize, inline
    TAG_SIZEF = -16,       // QSizeF, inline
    TAG_RECT = -17,        // QRect, inline
    TAG_RECTF = -18,       // QRectF, `reference` points to a GC-allocated copy
  };

  // Crystal type id, as in Object#crystal_type_id, or a `Tag`.
  int32_t typeId;

  // The object data.  If this CrytalObject is a value according to *flags*,
  // then the *object* isn't the actual object:  Instead, it's replaced, and
  // extended by, the actual value.  This retains all semantics and avoids
  // memory bloat, at the cost of complexity.
  union {
    void *reference; // For references, the pointer.
    uint8_t bytes[INLINE_SIZE];
  };

  bool isNull() { return (this->typeId == CRYSTAL_NIL_ID); }

  // A CrystalVariant of *tag* without data.
  static CrystalVariant tagged(int32_t tag) {
    CrystalVariant object;
    memset(&object, 0, sizeof(object));
    object.typeId = tag;
    return object;
  }

  // A CrystalVariant of *tag* holding *value* inline.
  template <typename T>
  static CrystalVariant tagged(int32_t tag, const T &value) {
    static_assert(sizeof(T) <= INLINE_SIZE, "Value too large to inline");
    CrystalVariant object = tagged(tag);
    memcpy(object.bytes, &value, sizeof(T));
    return object;
  }

  // A CrystalVariant of *tag* referencing a GC-allocated copy of *value*.
  template <typename T>
  static CrystalVariant boxed(int32_t tag, const T &value) {
    CrystalVariant object = tagged(tag);
    object.reference = new (UseGC, bindgen_gc_finalizer<T>()) T(value);
    return object;
  }

  // The inline value of type *T*.
  template <typename T>
  T inlined() const {
    static_assert(sizeof(T) <= INLINE_SIZE, "Value too large to inline");
    T value;
    memcpy(&value, this->bytes, sizeof(T));
    return value;
  }

  // The referenced value of type *T*.
  template <typename T>
  const T &referenced() const {
    return *static_cast<const T *>(this->reference);
  }
} __attribute__((packed));

// Make Qt aware of our structures
Q_DECLARE_METATYPE(CrystalVariant);

// Whether *variant* is null as Qt 6 defines it: invalid, or holding a null
// pointer.  Qt 5's `QVariant::isNull()` also looks into the value, so a null
// `QString` or `QDate` would count, which Qt 6 (and qt6.cr) unpack as the
// value instead: an empty `windowTitle` is `""`, not `nil`.
static bool qvariant_is_null(const QVariant &variant) {
  if (!variant.isValid()) {
    return true;
  }

  const char *typeName = variant.typeName();
  size_t length = typeName ? strlen(typeName) : 0;
  return length > 0 && typeName[length - 1] == '*' && variant.isNull();
}

// Converts a QVariant into a CrystalVariant: a wrapped Crystal value is
// returned as it was, a value of a native Qt type listed in
// `CrystalVariant::Tag` is tagged, any other is `TAG_UNKNOWN`.
static CrystalVariant qvariant_to_crystal(const QVariant &variant) {
  int id = qRegisterMetaType<CrystalVariant>();

  if (qvariant_is_null(variant)) { // QVariant() == nil
    return CrystalVariant::tagged(CrystalVariant::CRYSTAL_NIL_ID);
  } else if (variant.userType() == id) {
    return variant.value<CrystalVariant>();
  }

  switch (variant.userType()) {
    case QMetaType::Bool:
      return CrystalVariant::tagged(CrystalVariant::TAG_BOOL, static_cast<uint8_t>(variant.toBool() ? 1 : 0));
    case QMetaType::Int:
    case QMetaType::Short:
    case QMetaType::Char:
    case QMetaType::SChar:
      return CrystalVariant::tagged(CrystalVariant::TAG_INT32, static_cast<int32_t>(variant.toInt()));
    case QMetaType::UInt:
    case QMetaType::UShort:
    case QMetaType::UChar:
      return CrystalVariant::tagged(CrystalVariant::TAG_UINT32, static_cast<uint32_t>(variant.toUInt()));
    case QMetaType::LongLong:
    case QMetaType::Long:
      return CrystalVariant::tagged(CrystalVariant::TAG_INT64, static_cast<int64_t>(variant.toLongLong()));
    case QMetaType::ULongLong:
    case QMetaType::ULong:
      return CrystalVariant::tagged(CrystalVariant::TAG_UINT64, static_cast<uint64_t>(variant.toULongLong()));
    case QMetaType::Float:
      return CrystalVariant::tagged(CrystalVariant::TAG_FLOAT32, variant.toFloat());
    case QMetaType::Double:
      return CrystalVariant::tagged(CrystalVariant::TAG_FLOAT64, variant.toDouble());
    case QMetaType::QChar:
      return CrystalVariant::tagged(CrystalVariant::TAG_CHAR, static_cast<uint32_t>(variant.toChar().unicode()));
    case QMetaType::QString:
      return CrystalVariant::tagged(CrystalVariant::TAG_STRING, qstring_to_crystal(variant.toString()));
    case QMetaType::QByteArray:
      return CrystalVariant::tagged(CrystalVariant::TAG_BYTES, qbytearray_to_crystal(variant.toByteArray()));
    case QMetaType::QStringList:
      return CrystalVariant::boxed(CrystalVariant::TAG_STRING_LIST, variant.toStringList());
    case QMetaType::QPoint:
      return CrystalVariant::tagged(CrystalVariant::TAG_POINT, variant.toPoint());
    case QMetaType::QPointF:
      return CrystalVariant::tagged(CrystalVariant::TAG_POINTF, variant.toPointF());
    case QMetaType::QSize:
      return CrystalVariant::tagged(CrystalVariant::TAG_SIZE, variant.toSize());
    case QMetaType::QSizeF:
      return CrystalVariant::tagged(CrystalVariant::TAG_SIZEF, variant.toSizeF());
    case QMetaType::QRect:
      return CrystalVariant::tagged(CrystalVariant::TAG_RECT, variant.toRect());
    case QMetaType::QRectF:
      return CrystalVariant::boxed(CrystalVariant::TAG_RECTF, variant.toRectF());
    default:
      return CrystalVariant::tagged(CrystalVariant::TAG_UNKNOWN);
  }
}

// Converts a CrystalVariant into a QVariant: a tagged value becomes the native
// QVariant of its type, copying the data Crystal owns, any other Crystal value
// is wrapped as is.
static QVariant crystal_to_qvariant(CrystalVariant object) {
  qRegisterMetaType<CrystalVariant>();

  switch (object.typeId) {
    case CrystalVariant::CRYSTAL_NIL_ID:
    case CrystalVariant::TAG_UNKNOWN:
      return QVariant();
    case CrystalVariant::TAG_BOOL:
      return QVariant(object.bytes[0] != 0);
    case CrystalVariant::TAG_INT32:
      return QVariant(static_cast<int>(object.inlined<int32_t>()));
    case CrystalVariant::TAG_UINT32:
      return QVariant(static_cast<unsigned int>(object.inlined<uint32_t>()));
    case CrystalVariant::TAG_INT64:
      return QVariant(static_cast<qlonglong>(object.inlined<int64_t>()));
    case CrystalVariant::TAG_UINT64:
      return QVariant(static_cast<qulonglong>(object.inlined<uint64_t>()));
    case CrystalVariant::TAG_FLOAT32:
      return QVariant(object.inlined<float>());
    case CrystalVariant::TAG_FLOAT64:
      return QVariant(object.inlined<double>());
    case CrystalVariant::TAG_CHAR: {
      char32_t codepoint = object.inlined<uint32_t>();
      if (codepoint <= 0xFFFF) {
        return QVariant(QChar(static_cast<char16_t>(codepoint)));
      } else { // Outside the BMP: QChar can't hold it, so a QString must.
        return QVariant(QString::fromUcs4(&codepoint, 1));
      }
    }
    case CrystalVariant::TAG_STRING: {
      CrystalString string = object.inlined<CrystalString>();
      return QVariant(QString::fromUtf8(string.ptr, string.size));
    }
    case CrystalVariant::TAG_BYTES: {
      CrystalString bytes = object.inlined<CrystalString>();
      return QVariant(QByteArray(bytes.ptr, bytes.size));
    }
    case CrystalVariant::TAG_STRING_LIST:
      return QVariant(object.referenced<QStringList>());
    case CrystalVariant::TAG_POINT:
      return QVariant(object.inlined<QPoint>());
    case CrystalVariant::TAG_POINTF:
      return QVariant(object.inlined<QPointF>());
    case CrystalVariant::TAG_SIZE:
      return QVariant(object.inlined<QSize>());
    case CrystalVariant::TAG_SIZEF:
      return QVariant(object.inlined<QSizeF>());
    case CrystalVariant::TAG_RECT:
      return QVariant(object.inlined<QRect>());
    case CrystalVariant::TAG_RECTF:
      return QVariant(object.referenced<QRectF>());
    default:
      if (object.typeId < 0) { // A tag this version doesn't know
        return QVariant();
      }

      return QVariant::fromValue<CrystalVariant>(object);
  }
}
