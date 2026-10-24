/* This file is part of bindgen
 *   See: https://github.com/Papierkorb/bindgen
 *
 * This file is licensed under the following "public domain" license.
 * IT APPLIES ONLY TO THIS FILE `bindgen_helper.h` AND NOT TO ANY OTHER FILE.
 *
 * This is free and unencumbered software released into the public domain.
 *
 * Anyone is free to copy, modify, publish, use, compile, sell, or
 * distribute this software, either in source code form or as a compiled
 * binary, for any purpose, commercial or non-commercial, and by any
 * means.
 *
 * In jurisdictions that recognize copyright laws, the author or authors
 * of this software dedicate any and all copyright interest in the
 * software to the public domain. We make this dedication for the benefit
 * of the public at large and to the detriment of our heirs and
 * successors. We intend this dedication to be an overt act of
 * relinquishment in perpetuity of all present and future rights to this
 * software under copyright law.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * For more information, please refer to <http://unlicense.org/>
 */

 /*********************** TAKE CARE WHEN CHANGING THINGS ***********************
 * This file may be a symlink, pointing at the `bindgen_helper.hpp` inside the *
 * shard installation directory of `bindgen`.  It is *not* a local copy!   If  *
 * you want to make changes, make sure that you have your own copy first, and  *
 * only then do changes.  Otherwise a bindgen update may override your changes.*
 ******************************************************************************/

#ifndef BINDGEN_HELPER_HPP
#define BINDGEN_HELPER_HPP

#include <gc/gc.h> // Boehm GC
#include <string.h>
#include <stdlib.h> // abort()
#include <stdio.h> // fprintf()
#include <stdint.h> // uintptr_t

// Helper structure to transfer a `String` between C/C++ and Crystal.
typedef struct CrystalString { // C compatibility
  const char *ptr;
  int size;
} CrystalString;

// Compiler branching hint
#define bindgen_likely(x) __builtin_expect(!!(x), 1)

static __attribute__((noreturn)) void bindgen_fatal_panic(const char *message) {
  fprintf(stderr, "Fatal error in bindings: %s\n", message);
  abort();
}

#ifdef __cplusplus
#include <gc/gc_cpp.h>
#include <functional>
#include <initializer_list>
#include <memory>
#include <mutex>
#include <string>
#include <type_traits>
#include <typeindex>
#include <typeinfo>
#include <unordered_map>
#include <utility>
#include <vector>

// The wrapper functions return copied structures by value, which Crystal knows
// as `lib struct` of the same layout.  Clang warns if such a type isn't a POD,
// which already is the case if it has a constructor.
#ifdef __clang__
#pragma clang diagnostic ignored "-Wreturn-type-c-linkage"
#endif

#if defined(__GXX_RTTI) || defined(_CPPRTTI)
#define BINDGEN_HAS_RTTI 1
#define BINDGEN_TYPEID(T) (&typeid(T))
#else
#define BINDGEN_HAS_RTTI 0
#define BINDGEN_TYPEID(T) (nullptr)
#endif

// Downcast used by `#to?` of the Crystal wrappers.  Without RTTI, like Qt's
// `-fno-rtti` builds, the cast can't be checked: it fails at run-time instead.
template <typename To, typename From>
static To bindgen_dynamic_cast(From *from) {
#if BINDGEN_HAS_RTTI
  return dynamic_cast<To>(from);
#else
  (void)from;
  bindgen_fatal_panic("Downcasting with #to? needs C++ RTTI, which is disabled");
#endif
}

/* Holds the `CrystalProc` *proc* for the lambda a `std::function` argument is
 * built from, see SPEC.md §2.2.6.  The copy lives in memory the GC scans but
 * doesn't collect, so the Crystal closure the proc refers to stays alive as
 * long as the `std::function`, which C++ may store anywhere, and is freed
 * with the last copy of the lambda.  A plain copy in the lambda wouldn't do:
 * memory C++ allocates, like the `std::function`'s or that of the object
 * storing it, isn't scanned.
 */
template <typename Proc>
static std::shared_ptr<Proc> bindgen_hold_proc(const Proc &proc) {
  Proc *held = new (NoGC) Proc(proc);
  return std::shared_ptr<Proc>(held, [](Proc *p) { GC_FREE(p); });
}

/* Type discovery, see SPEC.md §2.3.7: finds the wrapped class of the object a
 * `Base` pointer points to, so that the wrapper is of the most derived class
 * the binding knows.  The generated `DISCOVER` function of a class holds the
 * table of the wrapped classes inheriting from it in Crystal, the deepest
 * first, each with the `id` the Crystal side maps to the wrapper class and a
 * `dynamic_cast` to it.  The dynamic type is looked up by `typeid`; a type not
 * in the table, like a private sub-class or the shadow class of a Crystal
 * sub-class, is walked through the casts once, and the result remembered.
 * `crystal` receives the Crystal object which constructed the object, see
 * `bindgen_crystal_object`, or null; the Crystal side checks its class and
 * prefers it.  Without RTTI, or for a null pointer, nothing is discovered:
 * `id` is 0 and the pointer is returned as is, which the Crystal side wraps as
 * the class declared.
 */
template <typename Base>
struct BindgenTypeDiscovery {
  struct Entry {
    const std::type_info *type;
    int id;
    void *(*cast)(Base *);
  };

  const std::vector<Entry> entries;
  std::unordered_map<std::type_index, const Entry *> known;
  std::mutex mutex;

  BindgenTypeDiscovery(std::initializer_list<Entry> list) : entries(list) {
#if BINDGEN_HAS_RTTI
    for (const Entry &entry : entries) {
      known.emplace(std::type_index(*entry.type), &entry);
    }
    known.emplace(std::type_index(typeid(Base)), nullptr);
#endif
  }

  void *discover(Base *self, int *id, void **crystal) {
    *crystal = self ? bindgen_crystal_object(self) : nullptr;

#if BINDGEN_HAS_RTTI
    if (self) {
      std::lock_guard<std::mutex> lock(mutex);
      std::type_index type(typeid(*self));
      auto it = known.find(type);

      if (it == known.end()) {
        const Entry *found = nullptr;
        for (const Entry &entry : entries) {
          if (entry.cast(self)) {
            found = &entry;
            break;
          }
        }

        it = known.emplace(type, found).first;
      }

      if (const Entry *entry = it->second) {
        *id = entry->id;
        return entry->cast(self);
      }
    }
#endif

    *id = 0;
    return self;
  }
};

// Break C++'s encapsulation to allow easy wrapping of protected methods.
#define protected public

// The result points into `str`, whose owner has to keep it alive.
static CrystalString bindgen_stdstring_to_crystal(const std::string &str) {
  return CrystalString{ str.data(), static_cast<int>(str.size()) };
}

// A temporary, like the result of a function returning a `std::string` by
// value, is destroyed before the wrapper function returns.  Its bytes are
// copied into memory owned by the GC, so that they outlive the call.
static CrystalString bindgen_stdstring_to_crystal(const std::string &&str) {
  char *copy = static_cast<char *>(GC_MALLOC_ATOMIC(str.size() + 1));
  memcpy(copy, str.data(), str.size());
  copy[str.size()] = '\0';
  return CrystalString{ copy, static_cast<int>(str.size()) };
}

static std::string bindgen_crystal_to_stdstring(CrystalString str) {
  return std::string(str.ptr, str.size);
}

/* Wrapper for a Crystal `Slice`, see `Binding::CrystalSlice`.  `pointer` and
 * `size` lead, as in earlier versions which lacked `read_only`.
 */
struct CrystalSlice {
  const void *pointer;
  int size;
  bool read_only;
};

template<typename T, std::size_t N>
/*constexpr*/ CrystalSlice bindgen_array_to_slice(T (&arr)[N]) noexcept {
  return CrystalSlice{ arr, static_cast<int>(N), std::is_const<T>::value };
}

/* Wrapper for a C array of wrapped class instances, see `Binding::CrystalArray`
 * and `BindgenHelper::ArrayView`.  `assign` copy-assigns the element at its
 * second argument to the one at its first, it's null if `T` can't be
 * copy-assigned.
 */
struct CrystalArray {
  const void *pointer;
  int size;
  bool read_only;
  int element_size;
  void (*assign)(void *, const void *);
};

template<typename T>
void bindgen_array_assign(void *dst, const void *src) {
  *static_cast<T *>(dst) = *static_cast<const T *>(src);
}

template<typename T>
typename std::enable_if<std::is_copy_assignable<T>::value, void (*)(void *, const void *)>::type
bindgen_array_assigner() noexcept {
  return &bindgen_array_assign<T>;
}

template<typename T>
typename std::enable_if<!std::is_copy_assignable<T>::value, void (*)(void *, const void *)>::type
bindgen_array_assigner() noexcept {
  return nullptr;
}

template<typename T, std::size_t N>
CrystalArray bindgen_array_to_view(T (&arr)[N]) noexcept {
  return CrystalArray{
    arr, static_cast<int>(N), std::is_const<T>::value,
    static_cast<int>(sizeof(T)), bindgen_array_assigner<T>()
  };
}

/* Names the type `T` where C++'s declarator syntax can't, like a parameter
 * referring to an array: `bindgen_type<int [4]> &a` is `int (&a)[4]`.
 */
template<typename T>
using bindgen_type = T;

/* The address of `value`, also of a temporary, which lives until the end of
 * the full expression: a `CrystalProc` receives structures by pointer, and
 * only reads them.
 */
template <typename T>
T *bindgen_address(const T &value) {
  return const_cast<T *>(&value);
}

/* Wrapper for a Crystal `Proc`. */
template<typename T, typename ... Args>
struct CrystalProc {
  union {
    T (*withSelf)(void *, Args ...);
    T (*withoutSelf)(Args ...);
  };

  void *self;

  CrystalProc() : withSelf(nullptr), self(nullptr) { }

  inline bool isValid() const {
    return (withSelf != nullptr);
  }

  /* Fun fact: If the Crystal `Proc` doesn't capture any context, it won't
   * allocate any - But also don't expect any!  We have to accomodate for this
   * by only passing `this->self` iff it is non-NULL.
   */

  T operator()(Args ... arguments) const {
    if (this->self) {
      return this->withSelf(this->self, arguments...);
    } else {
      return this->withoutSelf(arguments...);
    }
  }
};

/* Functions called with the address of a wrapped object as C++ destroys it:
 * `delete` by C++ code owning it, like a Qt parent.  The generated module
 * registers `BindgenHelper.release`, so an object C++ deletes is released
 * from `keep_alive` without the program telling.  One list serves all bindings
 * of a program, as the definitions are weak and the linker keeps one of them:
 * each binding releases only the addresses it knows.  The list has no
 * destructor, as objects may be destroyed at exit, after static destructors.
 */
typedef void (*BindgenDestroyedHook)(void *);

struct BindgenDestroyedHooks {
  BindgenDestroyedHook hooks[16];
  int count;
};

extern "C" __attribute__((weak)) BindgenDestroyedHooks *bindgen_destroyed_hooks() {
  static BindgenDestroyedHooks hooks; // Zero-initialized
  return &hooks;
}

extern "C" __attribute__((weak)) void bindgen_add_destroyed_hook(BindgenDestroyedHook hook) {
  BindgenDestroyedHooks *hooks = bindgen_destroyed_hooks();
  if (hooks->count == static_cast<int>(sizeof(hooks->hooks) / sizeof(hooks->hooks[0]))) {
    bindgen_fatal_panic("Too many bindings registered a destroyed hook");
  }
  hooks->hooks[hooks->count++] = hook;
}

static void bindgen_notify_destroyed(void *object) {
  BindgenDestroyedHooks *hooks = bindgen_destroyed_hooks();
  for (int i = 0; i < hooks->count; ++i) hooks->hooks[i](object);
}

/* The key of the wrapped object at `object` in the table of kept objects of
 * `BindgenHelper`: the start of its GC allocation, so a pointer to a secondary
 * base of it, like the `QPaintDevice` of a `QWidget`, finds the same entry as
 * the object and as the destroyed hooks; the pointer itself for an object not
 * on the GC heap.  Weak, like the hooks: one definition serves all bindings.
 */
extern "C" __attribute__((weak)) void *bindgen_kept_key(void *object) {
  void *base = GC_base(object);
  return base ? base : object;
}

/* The bookkeeping of an object constructed from Crystal, the first base of
 * `CrystalGCCleanupWrapper<T>`.  Being its first dynamic base, it's its primary
 * base (Itanium C++ ABI), at the start of the allocation for every `T`, also a
 * dynamic one and the shadow subclass of `Processor::VirtualOverride`.  So the
 * glue of a method, which only has the `T *` of an object, finds it through
 * `GC_base`, see `bindgen_gc_object`.
 */
struct BindgenGCObject {
  BindgenGCObject() { }
  virtual ~BindgenGCObject() { }

  // Belongs to this object: a copy starts without dependencies.
  BindgenGCObject(const BindgenGCObject &) { }
  BindgenGCObject &operator=(const BindgenGCObject &) { return *this; }

  /* The objects this one depends on, see `bindgen_depends_on`: One pointer, or
   * a pointer to a GC-allocated array of them.  Only there for the GC to find
   * them when it scans this object.
   */
  void *bindgen_dependencies = nullptr;

  /* Set by the destructor, so the finalizer skips an object C++ destroyed,
   * and by the finalizer, so the destructor doesn't tell the hooks.
   */
  bool bindgen_destroyed = false;

  /* The Crystal object which constructed this one, see
   * `bindgen_set_crystal_object`: the type discovery hands it out again, so a
   * pointer to the object coming back from C++ is wrapped by the same Crystal
   * object (SPEC.md §2.3.7).  A weak reference: the pointer is hidden from the
   * GC and registered as a disappearing link, which the GC clears once the
   * Crystal object is unreachable.  A reference the GC saw would be a cycle
   * through this object, which keeps the finalizer, the destructor, from ever
   * running.  `bindgen_crystal_wrapped` is the address the Crystal object
   * wraps, the `T *` of the `CrystalGCCleanupWrapper<T>`: a pointer to a
   * secondary base, or to a member object, isn't wrapped by it.  A copy
   * starts without one.
   */
  void *bindgen_crystal = nullptr;
  void *bindgen_crystal_wrapped = nullptr;

  /* Tells a `BindgenGCObject` from other memory at the start of an allocation,
   * like a class allocated as it is or a Crystal object embedding a structure:
   * Its own address, scrambled so the GC doesn't take it for a pointer.
   */
  uintptr_t bindgen_check = bindgen_check_for(this);

  static uintptr_t bindgen_check_for(const BindgenGCObject *object) {
    return reinterpret_cast<uintptr_t>(object) ^ static_cast<uintptr_t>(0x5a17c0debe11a5edULL);
  }
};

/* Remembers *crystal*, the Crystal object which constructed the object at
 * *object*, in its `BindgenGCObject`, if it has one.  Weak, like the hooks.
 */
extern "C" __attribute__((weak)) void bindgen_set_crystal_object(void *object, void *crystal);

/* The Crystal object which constructed the object at *object*, if that is the
 * address it wraps, else null.  Weak, like the hooks.
 */
extern "C" __attribute__((weak)) void *bindgen_crystal_object(void *object);

/* The `BindgenGCObject` of the object at *self*, which may point into it, like
 * at the `T` of a `CrystalGCCleanupWrapper<T>`, or null if the object isn't one
 * constructed from Crystal.
 */
static BindgenGCObject *bindgen_gc_object(const void *self) {
  void *base = GC_base(const_cast<void *>(self));
  if (base == nullptr) return nullptr; // Not created by the binding
  if (GC_size(base) < sizeof(BindgenGCObject)) return nullptr;

  auto *object = static_cast<BindgenGCObject *>(base);
  if (object->bindgen_check != BindgenGCObject::bindgen_check_for(object)) return nullptr;
  return object;
}

extern "C" __attribute__((weak)) void bindgen_set_crystal_object(void *object, void *crystal) {
  BindgenGCObject *gc_object = bindgen_gc_object(object);
  if (gc_object == nullptr) return;

  gc_object->bindgen_crystal = reinterpret_cast<void *>(GC_HIDE_POINTER(crystal));
  gc_object->bindgen_crystal_wrapped = object;
  GC_general_register_disappearing_link(&gc_object->bindgen_crystal, crystal);
}

extern "C" __attribute__((weak)) void *bindgen_crystal_object(void *object) {
  BindgenGCObject *gc_object = bindgen_gc_object(object);
  if (gc_object == nullptr || gc_object->bindgen_crystal == nullptr) return nullptr;
  if (gc_object->bindgen_crystal_wrapped != object) return nullptr;

  return GC_REVEAL_POINTER(reinterpret_cast<GC_hidden_pointer>(gc_object->bindgen_crystal));
}

template <typename T>
struct CrystalGCCleanupWrapper: public BindgenGCObject, public T, public gc_cleanup
{
  using T::T;

  // Copy constructors aren't inherited.
  CrystalGCCleanupWrapper(const T &other) : T(other) { }

  /* Tells the hooks when C++ destroys the object.  The GC finalizer marked the
   * object before: It finalizes only an unreachable object, which nothing keeps
   * alive, so there's nothing to tell.  The objects this destructor deletes in
   * turn, like the children of a Qt parent, are told about.
   */
  ~CrystalGCCleanupWrapper() override {
    if (bindgen_destroyed) return;
    bindgen_destroyed = true;
    bindgen_notify_destroyed(static_cast<T *>(this));
  }

  /* C++ code owning this object, like a Qt parent, destroys it with `delete`.
   * This runs the destructor, but leaves the memory to the GC: When the object
   * and its owner became unreachable in the same collection, the GC queued the
   * finalizers of both already, and the one of the object would run on freed,
   * cleared memory.  `bindgen_cleanup` skips a destroyed object instead, and
   * the GC reclaims the memory once nothing refers to it.
   */
  static void operator delete(void *) { }
  static void operator delete(void *, GCPlacement) { }

  // `T` may declare members of these names too.
  using BindgenGCObject::bindgen_dependencies;
  using BindgenGCObject::bindgen_destroyed;

private:
  /* The finalizer, replacing `gc_cleanup::cleanup`, which can't tell an object
   * C++ destroyed from a live one.
   */
  static void bindgen_cleanup(void *base, void *displacement) {
    auto *self = reinterpret_cast<CrystalGCCleanupWrapper *>(static_cast<char *>(base) + reinterpret_cast<ptrdiff_t>(displacement));
    if (self->bindgen_destroyed) return;
    self->bindgen_destroyed = true;
    self->~CrystalGCCleanupWrapper();
  }

  // Registers `bindgen_cleanup` once `gc_cleanup` registered its own.
  struct Finalizer {
    Finalizer(CrystalGCCleanupWrapper *self) {
      void *base = GC_base(self);
      if (base == nullptr) return; // Not on the GC heap
      void *displacement = reinterpret_cast<void *>(reinterpret_cast<char *>(self) - static_cast<char *>(base));
      GC_register_finalizer_ignore_self(base, bindgen_cleanup, displacement, nullptr, nullptr);
    }
  } bindgen_finalizer{this};
};

// Stores *dependencies* in *object*, replacing those it had.  Null pointers are
// left out.
static void bindgen_set_dependencies(BindgenGCObject *object, std::initializer_list<const void *> dependencies) {
  size_t count = 0;
  const void *last = nullptr;
  for (const void *dependency : dependencies) {
    if (dependency) {
      ++count;
      last = dependency;
    }
  }

  if (count <= 1) {
    object->bindgen_dependencies = const_cast<void *>(last);
  } else {
    void **list = static_cast<void **>(GC_MALLOC(sizeof(void *) * count));
    void **slot = list;
    for (const void *dependency : dependencies) {
      if (dependency) *slot++ = const_cast<void *>(dependency);
    }
    object->bindgen_dependencies = list;
  }
}

/* Makes the GC destroy *object* before its *dependencies*: Objects it refers to
 * from memory the GC doesn't scan, like through a d-pointer, and uses in its
 * destructor, like an iterator unregistering from its container.  Stored in the
 * object, they stay alive as long as it does, and as the GC finalizes an object
 * before the objects it points to, they're finalized only after it.
 * Generated into the constructors configured in `depends_on:`.
 */
template <typename T>
CrystalGCCleanupWrapper<T> *bindgen_depends_on(CrystalGCCleanupWrapper<T> *object, std::initializer_list<const void *> dependencies) {
  bindgen_set_dependencies(object, dependencies);
  return object;
}

/* Same, for a method configured in `depends_on:`, called on *self* before the
 * method runs: The object depends on the *dependencies* from then on, instead
 * of those it had.  Does nothing for an object not constructed from Crystal,
 * which the GC doesn't finalize.
 */
static void bindgen_depends_on(const void *self, std::initializer_list<const void *> dependencies) {
  if (BindgenGCObject *object = bindgen_gc_object(self)) {
    bindgen_set_dependencies(object, dependencies);
  }
}

// Unions can't be inherited from, these are allocated as they are.  This
// doesn't run their destructor: bindgen uses `bindgen_gc_finalizer` instead.
template <typename T>
using CrystalGCWrapper = typename std::conditional<
  std::is_union<T>::value, T, CrystalGCCleanupWrapper<T>>::type;

template <typename T>
struct BindgenGCFinalizer {
  static void GC_CALLBACK run(void *object, void *) {
    static_cast<T *>(object)->~T();
  }

  static GCCleanUpFunc get(std::true_type /* trivially destructible */) {
    return nullptr;
  }

  static GCCleanUpFunc get(std::false_type) {
    return &BindgenGCFinalizer<T>::run;
  }
};

/* Finalizer for a `T` that is allocated as it is, instead of being wrapped in
 * a `CrystalGCWrapper`: `new (UseGC, bindgen_gc_finalizer<T>()) T { ... }`.
 * Aggregates are allocated like this, as only `T` itself can be initialized
 * from a braced list without copying or moving it, and so are unions.  Returns
 * a null pointer if `T` doesn't need a finalizer.
 */
template <typename T>
GCCleanUpFunc bindgen_gc_finalizer() {
  return BindgenGCFinalizer<T>::get(std::is_trivially_destructible<T>());
}

/// A simple wrapper around a non-pointer type that allows a single
/// dereference operation.
template <typename T>
struct bg_deref {
  T data;

  template<typename... Args>
  bg_deref(Args&&... args) : data(std::forward<Args>(args)...) {}

  T operator*() && { return std::move(data); }

  // Allows passing the value straight on into a converter function.
  operator T() && { return std::move(data); }
};

/* Access to the key and value an iterator of an associative container points
 * at.  Qt's iterators offer `key()` and `value()`, which are preferred, those
 * of the standard library point at a `std::pair`.  Pass `0` as second
 * argument.
 */
template <typename It>
auto bindgen_iterator_key(const It &it, int) -> decltype(it.key()) {
  return it.key();
}

template <typename It>
auto bindgen_iterator_key(const It &it, long) -> decltype((it->first)) {
  return it->first;
}

template <typename It>
auto bindgen_iterator_value(const It &it, int) -> decltype(it.value()) {
  return it.value();
}

template <typename It>
auto bindgen_iterator_value(const It &it, long) -> decltype((it->second)) {
  return it->second;
}

/* Returns the value of `key` in the associative container `map`.  The caller
 * checks that the key exists, through the container's `count` method.  Unlike
 * `map.at(key)` this never throws, and unlike `map[key]` it doesn't require
 * the value type to be default constructible.
 */
template <typename M>
const typename M::mapped_type &bindgen_map_fetch(const M &map, const typename M::key_type &key) {
  auto it = map.find(key);
  if (it == map.end()) bindgen_fatal_panic("Key not found in associative container");
  return bindgen_iterator_value(it, 0);
}

/* Sets the value of `key` in the associative container `map`, replacing an
 * existing value.  `map[key] = value` would require the value type to be
 * default constructible, and `insert_or_assign` requires C++17.
 */
template <typename M>
void bindgen_map_store(M &map, const typename M::key_type &key, const typename M::mapped_type &value) {
  auto it = map.find(key);
  if (it != map.end()) {
    bindgen_iterator_value(it, 0) = value;
  } else {
    map.emplace(key, value);
  }
}

/* The members of a pair `P`, like `std::pair` or `QPair`, which are fields
 * and not methods.
 */
template <typename P>
const typename P::first_type &bindgen_pair_first(const P &pair) {
  return pair.first;
}

template <typename P>
const typename P::second_type &bindgen_pair_second(const P &pair) {
  return pair.second;
}

template <typename P>
void bindgen_pair_set(P &pair, const typename P::first_type &first, const typename P::second_type &second) {
  pair.first = first;
  pair.second = second;
}

/* Copy of all entries of an associative container `M`, taken at once.  The
 * entries are then accessed by index from Crystal, as C++ iterators can't be
 * passed to Crystal.  As it's a copy, changing the container while iterating
 * over the entries is safe.
 */
template <typename M>
struct BindgenMapEntries {
  typedef typename M::key_type key_type;
  typedef typename M::mapped_type mapped_type;

  std::vector<std::pair<key_type, mapped_type>> entries;

  BindgenMapEntries(const M &map) {
    entries.reserve(map.size());

    for (auto it = map.begin(); it != map.end(); ++it) {
      entries.emplace_back(bindgen_iterator_key(it, 0), bindgen_iterator_value(it, 0));
    }
  }

  int size() const { return static_cast<int>(entries.size()); }
  const key_type &key(int index) const { return entries[index].first; }
  const mapped_type &value(int index) const { return entries[index].second; }
};

#endif // __cplusplus
#endif // BINDGEN_HELPER_HPP
