#include <gc/gc.h> // Boehm GC
#include <cstring>
#include <QtCore/qbytearray.h>
#include <QtCore/qstring.h>
#include <QtCore/qvariant.h>

#include "bindgen_helper.hpp"

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
// ATTENTION: This structure, including its constants, are mirrored in Crystal.
//            Changes here must be reflected in Crystal, else happy debug times ensue!
struct CrystalVariant {
  // Size of the largest inline-able value.  Must be at least the size of a
  // pointer.
  static constexpr int INLINE_SIZE = 16; // 2 * sizeof(void*);

  // Crystal type id of `nil`.
  static constexpr int CRYSTAL_NIL_ID = 0;

  // Crystal type id, as in Object#crystal_type_id
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
} __attribute__((packed));

// Make Qt aware of our structures
Q_DECLARE_METATYPE(CrystalVariant);

static CrystalVariant qvariant_to_crystal(const QVariant &variant) {
  int id = qRegisterMetaType<CrystalVariant>();
  static constexpr CrystalVariant nil = CrystalVariant{ CrystalVariant::CRYSTAL_NIL_ID, nullptr };

  if (!variant.isValid() || variant.isNull()) { // QVariant() == nil
    return nil;
  } else if (variant.userType() == id) {
    return variant.value<CrystalVariant>();
  } else {
    // TODO: Try mapping a Qt type to a Crystal type and repack into a CrystalVariant
    return nil;
  }
}

static QVariant crystal_to_qvariant(CrystalVariant object) {
  qRegisterMetaType<CrystalVariant>();

  if (object.isNull()) {
    return QVariant(); // Fast path for `nil`
  }

  return QVariant::fromValue<CrystalVariant>(object);
}
