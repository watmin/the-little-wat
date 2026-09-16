;; probes/cache/lru-laws.wat: is :wat::cache::Lru actually an LRU, or a FIFO wearing the name?
;;
;; wat/cache.wat states its contract precisely, which is what makes it checkable:
;;
;;   put: "Returns the DISPLACED entry -- the least-recently-used one when the insert pushed
;;         past capacity, or `k`'s previous binding when `k` was already present -- and
;;         `:wat::core::None` when nothing was displaced."
;;   get: "`Some v` on a hit (WHICH BUMPS `k` TO MRU), `None` on a miss."
;;   len: "Current entry count (never above capacity). Read-only -- does not touch LRU order."
;;
;; The load-bearing clause is get's parenthetical. A cache that evicts in insertion order is a
;; FIFO; what makes it an LRU is that a READ counts as use. So the decisive case is:
;;
;;   cap 2, put a, put b, GET A, put c   ->  an LRU evicts b.  A FIFO evicts a.
;;
;; with the same sequence minus the get as the control -- without it, a build that always evicts
;; the oldest would pass the first case by accident.
;;
;; L4 also checks the second half of put's sentence (an update returns the PREVIOUS binding, not
;; an eviction) and that len does not grow, and L5 that len is bounded under sustained pressure.
;;
;; Expected: every line below prints PASS.
;;
;; Run: wat probes/cache/lru-laws.wat

(:wat::core::typealias :lc::C (:wat::cache::Lru :- [:wat::core::String :wat::core::i64]))
(:wat::core::typealias :lc::E (:wat::cache::Entry :- [:wat::core::String :wat::core::i64]))

(:wat::core::defn :lc::show [e <- (:wat::core::Option :- [:lc::E])] -> :wat::core::String
  (:wat::core::match e
    [:wat::core::Option.Some {:value en}
      (:wat::string::concat (:wat::cache::Entry/key en)
        (:wat::string::concat "=" (:wat::i64::to-string (:wat::cache::Entry/value en))))]
    [:wat::core::Option.None {} "none"]))

(:wat::core::defn :lc::check [label <- :wat::core::String
                              got   <- :wat::core::String
                              want  <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat (:wat::core::if (:wat::core::= got want) "PASS  " "FAIL  ")
      (:wat::string::concat label
        (:wat::string::concat "  got=" (:wat::string::concat got
          (:wat::string::concat " want=" want)))))))

(:wat::core::defn :lc::checki [label <- :wat::core::String
                               got   <- :wat::core::i64
                               want  <- :wat::core::i64] -> :wat::core::nil
  (:lc::check label (:wat::i64::to-string got) (:wat::i64::to-string want)))

;; L1 -- nothing is displaced while there is room.
(:wat::core::defn :lc::l1 [] -> :wat::core::nil
  (:wat::core::let [c (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] 2)
                    a (:wat::cache::Lru::put c "a" 1)
                    b (:wat::cache::Lru::put c "b" 2)]
    (:wat::core::do
      (:lc::check  "L1 put under capacity displaces nothing" (:lc::show a) "none")
      (:lc::check  "L1 second put still displaces nothing  " (:lc::show b) "none")
      (:lc::checki "L1 len after two puts                  " (:wat::cache::Lru::len c) 2))))

;; L2 -- THE LAW. A read counts as use, so the untouched key is the one that goes.
(:wat::core::defn :lc::l2 [] -> :wat::core::nil
  (:wat::core::let [c  (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] 2)
                    _1 (:wat::cache::Lru::put c "a" 1)
                    _2 (:wat::cache::Lru::put c "b" 2)
                    hit (:wat::cache::Lru::get c "a")
                    ev (:wat::cache::Lru::put c "c" 3)]
    (:wat::core::do
      (:lc::check "L2 get a hits                          "
        (:wat::core::match hit
          [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
          [:wat::core::Option.None {} "miss"]) "1")
      (:lc::check "L2 after get a, put c evicts b not a   " (:lc::show ev) "b=2")
      (:lc::check "L2 a survived                          "
        (:wat::core::match (:wat::cache::Lru::get c "a")
          [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
          [:wat::core::Option.None {} "miss"]) "1"))))

;; L3 -- the control: the SAME sequence with no get evicts the oldest.
(:wat::core::defn :lc::l3 [] -> :wat::core::nil
  (:wat::core::let [c  (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] 2)
                    _1 (:wat::cache::Lru::put c "a" 1)
                    _2 (:wat::cache::Lru::put c "b" 2)
                    ev (:wat::cache::Lru::put c "c" 3)]
    (:lc::check "L3 control: no get, put c evicts a     " (:lc::show ev) "a=1")))

;; L4 -- an update is not an eviction: it returns the previous binding and len holds.
(:wat::core::defn :lc::l4 [] -> :wat::core::nil
  (:wat::core::let [c  (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] 2)
                    _1 (:wat::cache::Lru::put c "a" 1)
                    up (:wat::cache::Lru::put c "a" 9)]
    (:wat::core::do
      (:lc::check  "L4 re-put returns previous binding     " (:lc::show up) "a=1")
      (:lc::checki "L4 len unchanged by an update          " (:wat::cache::Lru::len c) 1)
      (:lc::check  "L4 the new value is in place           "
        (:wat::core::match (:wat::cache::Lru::get c "a")
          [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
          [:wat::core::Option.None {} "miss"]) "9"))))

;; L5 -- len is bounded under sustained pressure.
(:wat::core::defn :lc::fill [c <- :lc::C n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [worst <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::do
        (:wat::cache::Lru::put c (:wat::i64::to-string i) i)
        (:wat::core::let [l (:wat::cache::Lru::len c)]
          (:wat::core::if (:wat::core::> l worst) l worst))))
    0
    (:wat::core::range 0 n)))

(:wat::core::defn :lc::l5 [] -> :wat::core::nil
  (:wat::core::let [c (:wat::cache::Lru::new :- [:wat::core::String :wat::core::i64] 3)]
    (:lc::checki "L5 len never exceeds capacity over 500  " (:lc::fill c 500) 3)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do (:lc::l1) (:lc::l2) (:lc::l3) (:lc::l4) (:lc::l5)))
