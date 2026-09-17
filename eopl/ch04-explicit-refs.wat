;; eopl/ch04-explicit-refs.wat — EOPL chapter 4's store, and what mutable state costs in wat.
;;
;; EOPL's store is an array indexed by reference. wat has no positional update on either vector
;; type (F-104), so the store is a `PersistentMap` keyed by index -- the same shape F-057 forces
;; on a visited set. wat's structure-sharing story is map-shaped.
;;
;; The chapter also answers a question every wat program eventually asks: **how do you hold
;; mutable state, and what does each way cost?** There are three answers and they are three orders
;; of magnitude apart, which is worth knowing before choosing one.
;;
;; Run: wat eopl/ch04-explicit-refs.wat

(:wat::load-file! "lib/refs.wat")

(:wat::core::defn :c4r::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c4r::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; let r = newref(5) in (setref(r,99); deref(r))
(:wat::core::defn :c4r::basic [] -> :ref::Exp
  (:ref::Exp.Let {:name "r" :e (:ref::Exp.NewRef {:e (:ref::Exp.Lit {:n 5})})
    :body (:ref::Exp.Seq {:a (:ref::Exp.SetRef {:r (:ref::Exp.Var {:name "r"}) :v (:ref::Exp.Lit {:n 99})})
                          :b (:ref::Exp.DeRef {:e (:ref::Exp.Var {:name "r"})})})}))

;; two refs stay independent
(:wat::core::defn :c4r::two-refs [] -> :ref::Exp
  (:ref::Exp.Let {:name "a" :e (:ref::Exp.NewRef {:e (:ref::Exp.Lit {:n 1})})
    :body (:ref::Exp.Let {:name "b" :e (:ref::Exp.NewRef {:e (:ref::Exp.Lit {:n 2})})
      :body (:ref::Exp.Seq {:a (:ref::Exp.SetRef {:r (:ref::Exp.Var {:name "a"}) :v (:ref::Exp.Lit {:n 10})})
                            :b (:ref::Exp.Add {:a (:ref::Exp.DeRef {:e (:ref::Exp.Var {:name "a"})})
                                               :b (:ref::Exp.DeRef {:e (:ref::Exp.Var {:name "b"})})})})})}))

;; a counter driven through the store: 200 increments
(:wat::core::defn :c4r::counter [n <- :wat::core::i64] -> :ref::Exp
  (:ref::Exp.Let {:name "r" :e (:ref::Exp.NewRef {:e (:ref::Exp.Lit {:n 0})})
    :body (:ref::Exp.Seq
            {:a (:ref::Exp.Rep {:times n
                  :body (:ref::Exp.SetRef {:r (:ref::Exp.Var {:name "r"})
                          :v (:ref::Exp.Add {:a (:ref::Exp.DeRef {:e (:ref::Exp.Var {:name "r"})})
                                             :b (:ref::Exp.Lit {:n 1})})})})
             :b (:ref::Exp.DeRef {:e (:ref::Exp.Var {:name "r"})})})}))

;; --- the three ways to hold mutable state in wat -----------------------------------------------
(:wat::core::typealias :c4r::PM (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

;; 1. THREADED: a PersistentMap passed along. Pure, no handles, no messages.
(:wat::core::defn :c4r::threaded [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [m <- :c4r::PM i <- :wat::core::i64] -> :c4r::PM
        (:wat::map::assoc m 0 (:wat::core::+ 1
          (:wat::core::match (:wat::map::get m 0)
            [:wat::core::Option.Some {:value v} v]
            [:wat::core::Option.None {} 0]))))
      (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) (:wat::core::range 0 n))
    [m (:wat::core::match (:wat::map::get m 0)
         [:wat::core::Option.Some {:value v} v]
         [:wat::core::Option.None {} 0])]))

;; 2. A THREAD-OWNED MUTABLE CELL: :wat::cache::Lru, the one wat exposes (see P-027)
(:wat::core::defn :c4r::celled [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:wat::cache::Lru::new :- [:wat::core::i64 :wat::core::i64] 4)]
    (:wat::core::do
      (:wat::cache::Lru::put c 0 0)
      (:wat::core::foldl
        (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
          (:wat::core::match (:wat::cache::Lru::get c 0)
            [:wat::core::Option.Some {:value v}
              (:wat::core::do (:wat::cache::Lru::put c 0 (:wat::core::+ v 1)) 0)]
            [:wat::core::Option.None {} 0]))
        0 (:wat::core::range 0 n))
      (:wat::core::match (:wat::cache::Lru::get c 0)
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} -1]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n 2000]
    (:wat::core::do
      (:c4r::say "newref / setref / deref     " (:wat::core::if (:wat::core::= (:ref::run (:c4r::basic)) 99) "PASS" "FAIL"))
      (:c4r::say "two refs stay independent   " (:wat::core::if (:wat::core::= (:ref::run (:c4r::two-refs)) 12) "PASS" "FAIL"))
      (:c4r::say "200 increments through refs " (:wat::core::if (:wat::core::= (:ref::run (:c4r::counter 200)) 200) "PASS" "FAIL"))
      (:wat::kernel::println "---- what one read-modify-write costs, three ways ----")
      (:wat::core::let
        [t0 (:c4r::now) a (:c4r::threaded n) e0 (:wat::core::- (:c4r::now) t0)
         t1 (:c4r::now) b (:c4r::celled n)   e1 (:wat::core::- (:c4r::now) t1)]
        (:wat::core::do
          (:c4r::say "  threaded PersistentMap (pure)   "
            (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
              (:wat::i64::to-string (:wat::core::/ e0 n)) " ns    (result " (:wat::i64::to-string a) ")")))
          (:c4r::say "  :wat::cache::Lru (mutable cell)  "
            (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
              (:wat::i64::to-string (:wat::core::/ e1 n)) " ns    (result " (:wat::i64::to-string b) ")")))
          (:wat::kernel::println "     a service: ~448000 ns -- two messages at F-051's measured 224 us each (derived, not re-run here)"))))))
