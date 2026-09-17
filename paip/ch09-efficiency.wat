;; PAIP chapter 9 (efficiency issues: memoization and indexing), in wat.
;;
;; The chapter's headline technique is MEMOIZATION, and the interesting part is a guess that
;; turned out to be wrong.
;;
;; Norvig's `memoize` is a HIGHER-ORDER function: it takes any function and returns a memoized
;; version with the same signature, holding a hidden table, so callers are untouched. The obvious
;; guess is that wat cannot write that, because it has no mutation (C-053).
;;
;; **The obvious guess is wrong.** A closure CAN capture a `:wat::cache::Lru`, so the transparent
;; wrapper is writable and behaves exactly as Norvig's -- verified in
;; `probes/paip/transparent-memoize.wat`: the second call with the same argument does not
;; recompute. That probe exists because this header first said it was impossible.
;;
;; What it costs is worth having written down, because three of the four are the same complaints
;; `okasaki/lib/susp.wat` makes (P-027) and the fourth is new:
;;
;;   1. **an Lru is an EVICTING cache, not a memo table.** At capacity 2 it silently forgets, and
;;      the probe shows it recomputing a value it had. Harmless for `fib`; WRONG for anything
;;      memoized for identity -- hash-consing, interning -- where the whole point is that it never
;;      forgets. That is a different contract, not a tuning parameter.
;;   2. a cached read measures ~7251 ns against ~3583 ns for a plain call, so the cell costs about
;;      2x a function call; the saving must clear that bar before memoizing pays at all.
;;   3. `Lru` is `thread_owned`, so a memoized function cannot cross a thread boundary.
;;   4. capacity 0 panics (F-084), so the wrapper has to reject or clamp it.
;;
;; The chapter below still uses the THREADED table rather than the wrapper, for a reason that has
;; nothing to do with what is possible: threading makes the CALL COUNT observable, and the call
;; count is the measurement. Naive fib(20) costs **21891** calls; the memo costs **21**. A
;; transparent wrapper hides exactly the number the chapter is about.
;;
;; The ask that survives all this is **P-028**: an unbounded, non-evicting memo cell. P-027 asks
;; for a one-shot suspension; this is the keyed relative, and `Lru` is the wrong vehicle for both
;; for the same reason -- it is a cache, and a cache is allowed to forget.
;;
;; Indexing is the chapter's other half and needs nothing wat lacks: the last key of an 8-entry
;; scan costs 8 probes and the first costs 1, and that gap of 7 is what an index removes.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch09-efficiency.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch09-efficiency.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Table (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

;; ---- naive fib: the call count is the thing that hurts, so it is counted
(:wat::core::defenum :paip::FibAns :wat::enum::Pure
  :F [v <- :wat::core::i64  calls <- :wat::core::i64])

(:wat::core::defn :paip::fib [n <- :wat::core::i64 calls <- :wat::core::i64] -> :paip::FibAns
  (:wat::core::if (:wat::core::< n 2) (:paip::FibAns.F {:v n :calls (:wat::core::+ calls 1)})
    (:wat::core::match (:paip::fib (:wat::core::- n 1) (:wat::core::+ calls 1))
      [:paip::FibAns.F {:v a :calls c1}
        (:wat::core::match (:paip::fib (:wat::core::- n 2) c1)
          [:paip::FibAns.F {:v b :calls c2}
            (:paip::FibAns.F {:v (:wat::core::+ a b) :calls c2})])])))

(:wat::core::defn :paip::fib-v [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:paip::fib n 0) [:paip::FibAns.F {:v v :calls c} v]))

(:wat::core::defn :paip::fib-c [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:paip::fib n 0) [:paip::FibAns.F {:v v :calls c} c]))

;; ---- the memoized version. The table is THREADED, which is the part that is not Norvig's.
(:wat::core::defenum :paip::MemoAns :wat::enum::Pure
  :M [v <- :wat::core::i64  table <- :paip::Table  calls <- :wat::core::i64])

(:wat::core::defn :paip::memo-fib [n <- :wat::core::i64 table <- :paip::Table calls <- :wat::core::i64] -> :paip::MemoAns
  (:wat::core::match (:wat::map::get table n)
    ;; a hit costs nothing and is not counted as work
    [:wat::core::Option.Some {:value v} (:paip::MemoAns.M {:v v :table table :calls calls})]
    [:wat::core::Option.None {}
      (:wat::core::if (:wat::core::< n 2)
        (:paip::MemoAns.M {:v n :table (:wat::map::assoc table n n) :calls (:wat::core::+ calls 1)})
        (:wat::core::match (:paip::memo-fib (:wat::core::- n 1) table (:wat::core::+ calls 1))
          [:paip::MemoAns.M {:v a :table t1 :calls c1}
            (:wat::core::match (:paip::memo-fib (:wat::core::- n 2) t1 c1)
              [:paip::MemoAns.M {:v b :table t2 :calls c2}
                (:wat::core::let [v (:wat::core::+ a b)]
                  (:paip::MemoAns.M {:v v :table (:wat::map::assoc t2 n v) :calls c2}))])]))]))

(:wat::core::defn :paip::mf [n <- :wat::core::i64] -> :paip::MemoAns
  (:paip::memo-fib n (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0))

(:wat::core::defn :paip::mf-v [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:paip::mf n) [:paip::MemoAns.M {:v v :table t :calls c} v]))

(:wat::core::defn :paip::mf-c [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:paip::mf n) [:paip::MemoAns.M {:v v :table t :calls c} c]))

;; ---- indexing: a scan, with its probes counted
(:wat::core::typealias :paip::Keys (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defenum :paip::ScanAns :wat::enum::Pure
  :S [found <- :wat::core::bool  v <- :wat::core::i64  probes <- :wat::core::i64])

(:wat::core::defn :paip::entries [] -> :paip::Keys
  (:wat::core::Vector :- [:wat::core::String] "a" "b" "c" "d" "e" "f" "g" "h"))

(:wat::core::defn :paip::scan [k <- :wat::core::String i <- :wat::core::i64 probes <- :wat::core::i64] -> :paip::ScanAns
  (:wat::core::let [es (:paip::entries)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length es))
      (:paip::ScanAns.S {:found false :v 0 :probes probes})
      (:wat::core::if (:wat::core::= k (:wat::core::nth es i))
        (:paip::ScanAns.S {:found true :v (:wat::core::+ i 1) :probes (:wat::core::+ probes 1)})
        (:paip::scan k (:wat::core::+ i 1) (:wat::core::+ probes 1))))))

(:wat::core::defn :paip::scan-v [k <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:paip::scan k 0 0)
    [:paip::ScanAns.S {:found f :v v :probes p} (:wat::core::if f (:wat::i64::to-string v) "#f")]))

(:wat::core::defn :paip::scan-p [k <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:paip::scan k 0 0) [:paip::ScanAns.S {:found f :v v :probes p} p]))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:paip::check-chapter "oracle/paip/ch09-efficiency.expected"
                          "paip ch09 efficiency"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::fib-v 10))
                            (int (:paip::fib-c 10))
                            (int (:paip::fib-v 20))
                            (int (:paip::fib-c 20))
                            ;; the tree has 2*fib(n+1)-1 nodes, which is why it is exponential
                            (:paip::b (:wat::core::= (:paip::fib-c 10)
                                        (:wat::core::- (:wat::core::* 2 (:paip::fib-v 11)) 1)))
                            (int (:paip::mf-v 10))
                            (int (:paip::mf-c 10))
                            (int (:paip::mf-v 20))
                            (int (:paip::mf-c 20))
                            (int (:paip::mf-v 30))
                            (int (:paip::mf-c 30))
                            (:paip::b (:wat::core::= (:paip::mf-v 20) (:paip::fib-v 20)))
                            (:paip::b (:wat::core::< (:paip::mf-c 20) (:paip::fib-c 20)))
                            (:paip::scan-v "a")
                            (int (:paip::scan-p "a"))
                            (:paip::scan-v "h")
                            (int (:paip::scan-p "h"))
                            (int (:wat::core::- (:paip::scan-p "h") (:paip::scan-p "a")))
                            (:paip::scan-v "z")))))
