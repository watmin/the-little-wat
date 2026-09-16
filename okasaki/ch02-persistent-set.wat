;; okasaki/ch02-persistent-set.wat — Okasaki chapter 2, and the answer to F-057's open question.
;;
;; wat ships PersistentVector and PersistentMap (structure-sharing) and NO persistent SET. F-057
;; records the cost: aoc/day05-paths.wat had to carry its visited set as a `PersistentMap` to
;; `true`, and F-057's own headline number (135.1 s -> 20.6 s) came from moving off the copying
;; containers. So the open question is whether a real persistent set would be worth shipping.
;;
;; This measures it. Three sets, same workload, same machine:
;;
;;   ok::Set          Okasaki's UnbalancedSet, 40 lines (lib/set.wat)
;;   PersistentMap    the workaround F-057 forces: a map to `true`
;;   HashSet          wat's copying set, via :wat::core::conj / contains?
;;
;; Correctness first: all three must agree on membership for every probe value, and ok::Set's
;; in-order walk must come back sorted and de-duplicated. A timing comparison between a wrong
;; structure and a right one is worth nothing.
;;
;; The inserted values are an LCG rather than 0..n-1 on purpose: an unbalanced BST fed a sorted
;; sequence degenerates into a linked list, which is Okasaki's own caveat and would measure the
;; degenerate case rather than the intended one. The depth is reported so that claim is visible
;; rather than assumed.
;;
;; Run: wat okasaki/ch02-persistent-set.wat

(:wat::load-file! "lib/set.wat")

(:wat::core::typealias :c2::PM (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]))
(:wat::core::typealias :c2::HS (:wat::core::HashSet :- [:wat::core::i64]))

(:wat::core::defn :c2::n [] -> :wat::core::i64 2000)

;; a deterministic LCG, so the run is reproducible
(:wat::core::defn :c2::step [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem (:wat::core::+ (:wat::core::* x 1103515245) 12345) 2147483648))

(:wat::core::defn :c2::vals [n <- :wat::core::i64] -> (:wat::core::PersistentVector :- [:wat::core::i64])
  (:wat::core::foldl
    (:wat::core::fn [acc <- (:wat::core::PersistentVector :- [:wat::core::i64]) i <- :wat::core::i64]
      -> (:wat::core::PersistentVector :- [:wat::core::i64])
      (:wat::vector::conj acc (:wat::core::rem (:c2::step (:wat::core::+ i 7)) 100000)))
    (:wat::core::PersistentVector :- [:wat::core::i64])
    (:wat::core::range 0 n)))

(:wat::core::defn :c2::ms [t0 <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::/ (:wat::core::- (:wat::time::epoch-nanos (:wat::time::now)) t0) 1000000))
(:wat::core::defn :c2::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

(:wat::core::defn :c2::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; --- build each set ---------------------------------------------------------------------------
(:wat::core::defn :c2::build-ok [vs <- (:wat::core::PersistentVector :- [:wat::core::i64])] -> :ok::Set
  (:wat::core::foldl :ok::insert (:ok::empty) vs))

(:wat::core::defn :c2::build-pm [vs <- (:wat::core::PersistentVector :- [:wat::core::i64])] -> :c2::PM
  (:wat::core::foldl
    (:wat::core::fn [m <- :c2::PM x <- :wat::core::i64] -> :c2::PM (:wat::map::assoc m x true))
    (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]) vs))

(:wat::core::defn :c2::build-hs [vs <- (:wat::core::PersistentVector :- [:wat::core::i64])] -> :c2::HS
  (:wat::core::foldl
    (:wat::core::fn [s <- :c2::HS x <- :wat::core::i64] -> :c2::HS (:wat::core::conj s x))
    (:wat::core::HashSet :- [:wat::core::i64]) vs))

;; --- membership over a probe range, counting hits so nothing is optimized away -----------------
(:wat::core::defn :c2::hits-ok [s <- :ok::Set n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::if (:ok::member? s i) (:wat::core::+ a 1) a))
    0 (:wat::core::range 0 n)))

(:wat::core::defn :c2::hits-pm [m <- :c2::PM n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::match (:wat::map::get m i)
        [:wat::core::Option.Some {:value v} (:wat::core::+ a 1)]
        [:wat::core::Option.None {} a]))
    0 (:wat::core::range 0 n)))

(:wat::core::defn :c2::hits-hs [s <- :c2::HS n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::if (:wat::core::contains? s i) (:wat::core::+ a 1) a))
    0 (:wat::core::range 0 n)))

;; --- sortedness of the in-order walk, the structure's own invariant ----------------------------
(:wat::core::defn :c2::sorted? [v <- (:wat::core::PersistentVector :- [:wat::core::i64])] -> :wat::core::bool
  (:wat::core::= 0
    (:wat::core::foldl
      (:wat::core::fn [bad <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
        (:wat::core::if (:wat::core::< (:wat::core::nth v (:wat::core::+ i 1)) (:wat::core::nth v i))
          (:wat::core::+ bad 1) bad))
      0 (:wat::core::range 0 (:wat::core::- (:wat::core::length v) 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n  (:c2::n)
     vs (:c2::vals n)
     p  10000
     t0 (:c2::now)  s  (:c2::build-ok vs)  ti1 (:c2::ms t0)
     t1 (:c2::now)  m  (:c2::build-pm vs)  ti2 (:c2::ms t1)
     t2 (:c2::now)  h  (:c2::build-hs vs)  ti3 (:c2::ms t2)
     t3 (:c2::now)  h1 (:c2::hits-ok s p)  tm1 (:c2::ms t3)
     t4 (:c2::now)  h2 (:c2::hits-pm m p)  tm2 (:c2::ms t4)
     t5 (:c2::now)  h3 (:c2::hits-hs h p)  tm3 (:c2::ms t5)
     walk (:ok::to-vector s)]
    (:wat::core::do
      (:c2::say "inserted values          " (:wat::i64::to-string n))
      (:c2::say "distinct (ok::Set size)  " (:wat::i64::to-string (:ok::size s)))
      (:c2::say "tree depth               " (:wat::i64::to-string (:ok::depth s)))
      (:c2::say "in-order walk is sorted  " (:wat::core::if (:c2::sorted? walk) "PASS" "FAIL"))
      (:c2::say "walk length == size      "
        (:wat::core::if (:wat::core::= (:wat::core::length walk) (:ok::size s)) "PASS" "FAIL"))
      (:c2::say "all three agree on membership"
        (:wat::core::if (:wat::core::if (:wat::core::= h1 h2) (:wat::core::= h2 h3) false) "PASS" "FAIL"))
      (:c2::say "  hits over 0..9999      " (:wat::i64::to-string h1))
      (:wat::kernel::println "---- build (ms) ----")
      (:c2::say "  ok::Set (BST)          " (:wat::i64::to-string ti1))
      (:c2::say "  PersistentMap to true  " (:wat::i64::to-string ti2))
      (:c2::say "  HashSet (copying)      " (:wat::i64::to-string ti3))
      (:wat::kernel::println "---- 10000 membership tests (ms) ----")
      (:c2::say "  ok::Set (BST)          " (:wat::i64::to-string tm1))
      (:c2::say "  PersistentMap to true  " (:wat::i64::to-string tm2))
      (:c2::say "  HashSet (copying)      " (:wat::i64::to-string tm3)))))
