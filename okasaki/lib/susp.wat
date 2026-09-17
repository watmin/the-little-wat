;; okasaki/lib/susp.wat — a memoized one-shot suspension: Okasaki's `$` / `force`.
;;
;; ┌─ THIS IS A STAND-IN. See PROVIDE.md P-027. ────────────────────────────────────────────────┐
;; │ The cell underneath is a `:wat::cache::Lru` at capacity 1, keyed 0, which is the wrong      │
;; │ vehicle on four counts:                                                                     │
;; │   1. an LRU is a BOUNDED EVICTING cache; a suspension is a one-shot NEVER-evicting cell.    │
;; │      At capacity 1 the eviction can never fire, so the recency list, the capacity bound     │
;; │      and the eviction path are dead weight on every access.                                 │
;; │   2. a cached `force` measures 7251 ns against 3583 ns for a plain call -- 2x a function    │
;; │      call for what should be a pointer read, and amortization has to fit in that budget.    │
;; │   3. capacity 0 panics (F-084), the key 0 is arbitrary, and nothing at the type level says  │
;; │      the cell holds exactly one thing.                                                      │
;; │   4. `Lru` is `scope = "thread_owned"`, so a suspension built this way cannot cross a       │
;; │      thread boundary -- a restriction a suspension has no reason to inherit.                │
;; │ The real thing is one word of state, `delay` and `force`, no eviction policy and no key.    │
;; └─────────────────────────────────────────────────────────────────────────────────────────────┘
;;
;; It is a `defstruct` and not a `defrecord` because the containment rule refuses a live handle in
;; a pure aggregate -- the same reason `:wat::cache::HolographicLru` is a defstruct. That refusal
;; is the type system working: `force` looks pure from its signature and is not.
;;
;; This does NOT change `:wat::stream::`. F-100 records that streams not memoizing is deliberate
;; (the Ruby Enumerator pattern: pull, process, discard, so a retained head cannot leak). This is
;; the other need -- force once EVER, shared between accessors -- and it wants its own type.

(:wat::core::defstruct :ok::Susp :- [T]
  [thunk <- [:-> :T]
   cell  <- (:wat::cache::Lru :- [:wat::core::i64 :T])])

(:wat::core::defn :ok::delay :- [T] [f <- [:-> :T]] -> (:ok::Susp :- [T])
  (:ok::Susp :- [T] :thunk f :cell (:wat::cache::Lru::new 1)))

(:wat::core::defn :ok::force :- [T] [s <- (:ok::Susp :- [T])] -> :T
  (:wat::core::match (:wat::cache::Lru::get (:ok::Susp/cell s) 0)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {}
      (:wat::core::let [v ((:ok::Susp/thunk s))]
        (:wat::core::do (:wat::cache::Lru::put (:ok::Susp/cell s) 0 v) v))]))

;; already forced? -- for tests that need to see whether the work has been paid
(:wat::core::defn :ok::forced? :- [T] [s <- (:ok::Susp :- [T])] -> :wat::core::bool
  (:wat::core::match (:wat::cache::Lru::get (:ok::Susp/cell s) 0)
    [:wat::core::Option.Some {:value v} true]
    [:wat::core::Option.None {} false]))
