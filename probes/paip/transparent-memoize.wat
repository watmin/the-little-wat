;; probes/paip/transparent-memoize.wat — can wat write Norvig's `memoize`?
;;
;; PAIP chapter 9's headline technique is a HIGHER-ORDER function that takes any function and
;; returns a memoized version WITH THE SAME SIGNATURE, holding a hidden table. Callers are
;; untouched; that is the whole appeal.
;;
;; The obvious guess is that wat cannot, because it has no mutation (C-053). **The obvious guess is
;; wrong, and this probe is why it is not claimed in C-084.** A closure CAN capture a
;; `:wat::cache::Lru`, so the wrapper is writable and behaves exactly as Norvig's:
;;
;;     first call, argument 7      "(computing)" then 49
;;     second call, argument 7     49            -- no recomputation
;;     third call, argument 8      "(computing)" then 64
;;
;; What it costs is the same three things `okasaki/lib/susp.wat` already complains about (P-027),
;; and one more that only shows up for a memo table:
;;
;;   1. an Lru is an EVICTING cache, not a memo table. Past its capacity it silently forgets, and a
;;      memoized function that forgets is a different contract from one that does not. Harmless for
;;      `fib`; wrong for anything memoized for IDENTITY (hash-consing, interning).
;;   2. a cached read measures ~7251 ns against ~3583 ns for a plain call, so the cell costs about
;;      2x a function call -- the saving has to clear that bar before memoizing pays.
;;   3. `Lru` is `scope = "thread_owned"`, so a memoized function cannot cross a thread boundary.
;;   4. capacity 0 panics (F-084), so the wrapper must reject or clamp it.
;;
;; Checked 2026-09-16, wat-rs a3218644d.

(:wat::core::defn :m::memoize [f <- [:wat::core::i64 :-> :wat::core::i64] cap <- :wat::core::i64]
  -> [:wat::core::i64 :-> :wat::core::i64]
  (:wat::core::let [cell (:wat::cache::Lru::new cap)]
    (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::match (:wat::cache::Lru::get cell n)
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {}
          (:wat::core::let [v (f n)]
            (:wat::core::do (:wat::cache::Lru::put cell n v) v))]))))

;; the underlying function announces itself, so a cache HIT is visible without a counter
(:wat::core::defn :m::slow [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do (:wat::kernel::println "  (computing)") (:wat::core::* n n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [fast (:m::memoize :m::slow 100)
                    ;; capacity 2, to show the EVICTION that makes this a cache and not a memo
                    tiny (:m::memoize :m::slow 2)]
    (:wat::core::do
      (:wat::kernel::println "---- the wrapper behaves as Norvig's ----")
      (:wat::kernel::println "first call, argument 7:")
      (:wat::kernel::println (:wat::i64::to-string (fast 7)))
      (:wat::kernel::println "second call, argument 7 (no recomputation expected):")
      (:wat::kernel::println (:wat::i64::to-string (fast 7)))
      (:wat::kernel::println "third call, argument 8:")
      (:wat::kernel::println (:wat::i64::to-string (fast 8)))

      (:wat::kernel::println "---- but at capacity 2 it FORGETS, which a memo table never does ----")
      (:wat::kernel::println (:wat::i64::to-string (tiny 1)))
      (:wat::kernel::println (:wat::i64::to-string (tiny 2)))
      (:wat::kernel::println (:wat::i64::to-string (tiny 3)))
      (:wat::kernel::println "asking for 1 again -- a real memo table would not recompute:")
      (:wat::kernel::println (:wat::i64::to-string (tiny 1))))))
