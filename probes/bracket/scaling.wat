;; probes/bracket/scaling.wat: does :wat::bracket::map actually run in parallel?
;;
;; probes/bracket/parallel-map.wat measured 16 equal items across 16 runners at 1.48x. A ratio
;; alone cannot say WHY -- a laptop drops its turbo clock when all cores are busy, so some of the
;; shortfall is the machine, not the pool.
;;
;; The test that separates them is SCALING. Hold the work per item fixed and vary the item count.
;; If the pool is genuinely parallel, wall time stays roughly FLAT from 1 item to runner-count
;; items. If the work is serialized, wall time grows linearly with the item count, exactly like
;; the sequential mapv beside it.
;;
;; It runs the sweep twice, once per locus. tools/bracket-os-oracle.sh supplies the third
;; number: the same burn in N independent OS processes, which is what this machine can actually
;; do with this interpreter on this work.
;;
;; Run: wat probes/bracket/scaling.wat

(:wat::core::typealias :bs::V (:wat::core::Vector :- [:wat::core::i64]))

;; ALLOCATION-FREE busywork. An earlier version of this probe used
;; (:wat::core::foldl ... (:wat::core::range 0 k)), which allocates a k-element Vector per call --
;; and a contended allocator would produce the same linear curve as serialized evaluation,
;; confounding the measurement. This is a tail-recursive countdown: no allocation at all.
(:wat::core::defn :bs::burn-loop [k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0)
    acc
    (:bs::burn-loop (:wat::core::- k 1) (:wat::core::rem (:wat::core::+ acc k) 1000003))))

(:wat::core::defn :bs::burn [k <- :wat::core::i64] -> :wat::core::i64
  (:bs::burn-loop k 0))

(:wat::core::defn :bs::unit [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::do (:bs::burn 100000) (:wat::core::* x 10)))

(:wat::core::defn :bs::ms-since [t0 <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::/ (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t0) 1000000))

(:wat::core::defn :bs::row [locus <- :wat::spawn::Locus n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [items (:wat::core::range 0 n)
     t0 (:wat::time::epoch-nanos (:wat::time::now))
     s  (:wat::core::mapv :bs::unit items)
     ts (:bs::ms-since t0)
     t1 (:wat::time::epoch-nanos (:wat::time::now))
     p  (:wat::bracket::map locus items
          (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:bs::unit x)))
     tp (:bs::ms-since t1)]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "items=" (:wat::i64::to-string n)
      "  seq=" (:wat::i64::to-string ts) "ms"
      "  par=" (:wat::i64::to-string tp) "ms"
      "  same=" (:wat::core::if (:wat::core::= s p) "yes" "NO"))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "runner-count=" (:wat::i64::to-string (:wat::spawn::runner-count (:wat::spawn::thread))))))
    (:wat::kernel::println "-- (:wat::spawn::thread) --")
    (:bs::row (:wat::spawn::thread) 1) (:bs::row (:wat::spawn::thread) 2)
    (:bs::row (:wat::spawn::thread) 4) (:bs::row (:wat::spawn::thread) 8)
    (:bs::row (:wat::spawn::thread) 16)
    (:wat::kernel::println "-- (:wat::spawn::process) --")
    (:bs::row (:wat::spawn::process) 1) (:bs::row (:wat::spawn::process) 2)
    (:bs::row (:wat::spawn::process) 4) (:bs::row (:wat::spawn::process) 8)
    (:bs::row (:wat::spawn::process) 16)))
