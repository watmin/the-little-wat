;; okasaki/lib/llist.wat — a lazy list: every CELL is a suspension, not one suspension per list.
;;
;; ┌─ SKELETON FOR P-027. Read this as the spec for the primitive, not as code to keep. ─────────┐
;; │ Each cell allocates its own `:wat::cache::Lru` (capacity 1, key 0), so a lazy list of n     │
;; │ costs n LRUs -- n recency lists, n capacity bounds, n eviction paths, none of which can     │
;; │ ever fire. This is where the stand-in stops being a constant-factor tax and becomes the     │
;; │ measurement. A real `Susp<T>` is one word; this is a cache per cons cell.                   │
;; │                                                                                              │
;; │ WHAT THE REAL PRIMITIVE MUST SUPPORT, as exercised below:                                   │
;; │   delay   : [:-> T] -> Susp<T>        deferred, not yet run                                 │
;; │   force   : Susp<T> -> T              run at most once, SHARED between accessors            │
;; │   forced? : Susp<T> -> bool           observable, so a test can prove incrementality        │
;; │ and it must be holdable in an aggregate that also shares its payload -- see the carrier      │
;; │ note below, which is the awkward part.                                                      │
;; └─────────────────────────────────────────────────────────────────────────────────────────────┘
;;
;; THE CARRIER. `:ok::LCell` must hold a suspension, so it cannot be a Pure enum (containment
;; rule) and must not be a record (F-098 deep-copies user-enum fields). An IMPURE enum is the one
;; shape that satisfies both -- the same needle chapter 6's carrier threads.

(:wat::load-file! "susp.wat")

(:wat::core::defenum :ok::LCell :wat::enum::Impure
  :CNil  []
  :CCons [h <- :wat::core::i64  t <- (:ok::Susp :- [:ok::LCell])])

(:wat::core::defn :ok::lnil [] -> (:ok::Susp :- [:ok::LCell])
  (:ok::delay (:wat::core::fn [] -> :ok::LCell (:ok::LCell.CNil {}))))

(:wat::core::defn :ok::lcons [x <- :wat::core::i64 t <- (:ok::Susp :- [:ok::LCell])]
  -> (:ok::Susp :- [:ok::LCell])
  (:ok::delay (:wat::core::fn [] -> :ok::LCell (:ok::LCell.CCons {:h x :t t}))))

(:wat::core::defn :ok::lnull? [s <- (:ok::Susp :- [:ok::LCell])] -> :wat::core::bool
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CNil {} true]
    [:ok::LCell.CCons {:h h :t t} false]))

(:wat::core::defn :ok::lhead [s <- (:ok::Susp :- [:ok::LCell])] -> :wat::core::i64
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CNil {} -1]
    [:ok::LCell.CCons {:h h :t t} h]))

(:wat::core::defn :ok::ltail [s <- (:ok::Susp :- [:ok::LCell])] -> (:ok::Susp :- [:ok::LCell])
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CNil {} s]
    [:ok::LCell.CCons {:h h :t t} t]))

(:wat::core::defn :ok::llen [s <- (:ok::Susp :- [:ok::LCell])] -> :wat::core::i64
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CNil {} 0]
    [:ok::LCell.CCons {:h h :t t} (:wat::core::+ 1 (:ok::llen t))]))
