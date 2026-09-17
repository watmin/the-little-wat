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

;; ─── the lazy-list vocabulary chapter 8's rebalancing needs ───────────────────────────────────
;; Each of these allocates a suspension per cell produced, so each is also a per-cell LRU under
;; the P-027 stand-in. `take` and `drop` are the pair that makes lazy rebuilding work: a deque
;; rebalances by splitting one end and reversing the remainder onto the other.

(:wat::core::defn :ok::ltake [s <- (:ok::Susp :- [:ok::LCell]) n <- :wat::core::i64]
  -> (:ok::Susp :- [:ok::LCell])
  (:ok::delay (:wat::core::fn [] -> :ok::LCell
    (:wat::core::if (:wat::core::<= n 0)
      (:ok::LCell.CNil {})
      (:wat::core::match (:ok::force s)
        [:ok::LCell.CNil {} (:ok::LCell.CNil {})]
        [:ok::LCell.CCons {:h h :t t}
          (:ok::LCell.CCons {:h h :t (:ok::ltake t (:wat::core::- n 1))})])))))

(:wat::core::defn :ok::ldrop [s <- (:ok::Susp :- [:ok::LCell]) n <- :wat::core::i64]
  -> (:ok::Susp :- [:ok::LCell])
  (:ok::delay (:wat::core::fn [] -> :ok::LCell
    (:wat::core::if (:wat::core::<= n 0)
      (:ok::force s)
      (:wat::core::match (:ok::force s)
        [:ok::LCell.CNil {} (:ok::LCell.CNil {})]
        [:ok::LCell.CCons {:h h :t t} (:ok::force (:ok::ldrop t (:wat::core::- n 1)))])))))

(:wat::core::defn :ok::lappend [a <- (:ok::Susp :- [:ok::LCell]) b <- (:ok::Susp :- [:ok::LCell])]
  -> (:ok::Susp :- [:ok::LCell])
  (:ok::delay (:wat::core::fn [] -> :ok::LCell
    (:wat::core::match (:ok::force a)
      [:ok::LCell.CNil {} (:ok::force b)]
      [:ok::LCell.CCons {:h h :t t} (:ok::LCell.CCons {:h h :t (:ok::lappend t b)})]))))

;; strict reverse: the rebalance reverses a finite prefix, and reversing lazily buys nothing
(:wat::core::defn :ok::lrev-onto [s <- (:ok::Susp :- [:ok::LCell]) acc <- (:ok::Susp :- [:ok::LCell])]
  -> (:ok::Susp :- [:ok::LCell])
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CNil {} acc]
    [:ok::LCell.CCons {:h h :t t} (:ok::lrev-onto t (:ok::lcons h acc))]))

(:wat::core::defn :ok::lrev [s <- (:ok::Susp :- [:ok::LCell])] -> (:ok::Susp :- [:ok::LCell])
  (:ok::lrev-onto s (:ok::lnil)))
