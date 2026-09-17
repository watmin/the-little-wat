;; okasaki/ch09-random-access-list.wat — Chapter 9, numerical representations.
;;
;; A different technique from everything before it: the structure MIRRORS A NUMBER SYSTEM. The
;; list is a sequence of binary digits, each Zero or One-carrying a complete tree of size 2^i, and
;; `cons` is binary increment with carry. The payoff is indexing — `lookup i` finds the right tree
;; in O(log n) and descends it in O(log n), where a cons list is O(n).
;;
;; Notably this chapter needs NO LAZINESS, so nothing here touches lib/susp.wat and none of these
;; numbers carry the P-027 stand-in's tax. After chapters 6-8 that is worth saying out loud: this
;; is what the measurements look like when the tooling is not in the way.
;;
;; Run: wat okasaki/ch09-random-access-list.wat

(:wat::load-file! "lib/ralist.wat")
(:wat::load-file! "lib/list.wat")

(:wat::core::defn :c9::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c9::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; cons 0..n-1, so element i holds (n-1-i)
(:wat::core::defn :c9::build [n <- :wat::core::i64] -> :ok::RList
  (:wat::core::foldl
    (:wat::core::fn [a <- :ok::RList i <- :wat::core::i64] -> :ok::RList (:ok::ra-cons a i))
    (:ok::ra-empty) (:wat::core::range 0 n)))

;; every index must read back what was put there
(:wat::core::defn :c9::check [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [l (:c9::build n)]
    (:wat::core::foldl
      (:wat::core::fn [bad <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
        (:wat::core::if (:wat::core::= (:ok::ra-lookup l i) (:wat::core::- (:wat::core::- n 1) i))
          bad (:wat::core::+ bad 1)))
      0 (:wat::core::range 0 n))))

;; the equivalent cons-list walk, for the comparison
(:wat::core::defn :c9::list-nth [l <- :ok::List i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= i 0)
    (:ok::head-or l -1)
    (:c9::list-nth (:ok::rest l) (:wat::core::- i 1))))

(:wat::core::defn :c9::build-list [n <- :wat::core::i64] -> :ok::List
  (:wat::core::foldl
    (:wat::core::fn [a <- :ok::List i <- :wat::core::i64] -> :ok::List (:ok::cons i a))
    (:ok::nil) (:wat::core::range 0 n)))

;; time k lookups spread across the whole structure
(:wat::core::defn :c9::row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [ra (:c9::build n)
     cl (:c9::build-list n)
     k 200
     step (:wat::core::/ n k)
     t1 (:c9::now)
     _1 (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
          (:wat::core::+ a (:ok::ra-lookup ra (:wat::core::* i step)))) 0 (:wat::core::range 0 k))
     e1 (:wat::core::- (:c9::now) t1)
     t2 (:c9::now)
     _2 (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
          (:wat::core::+ a (:c9::list-nth cl (:wat::core::* i step)))) 0 (:wat::core::range 0 k))
     e2 (:wat::core::- (:c9::now) t2)]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "  n=" (:wat::i64::to-string n)
      "   random-access list=" (:wat::i64::to-string (:wat::core::/ e1 k))
      "   cons list=" (:wat::i64::to-string (:wat::core::/ e2 k)) " ns/lookup")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c9::say "every index reads back, n=400"
      (:wat::core::if (:wat::core::= (:c9::check 400) 0) "PASS" "FAIL"))
    (:c9::say "size after 400 cons         " (:wat::i64::to-string (:ok::ra-size (:c9::build 400))))
    (:wat::kernel::println "---- lookup cost vs n  (O(log n): constant ADDITIVE step per doubling) ----")
    (:c9::row 400) (:c9::row 800) (:c9::row 1600) (:c9::row 3200)))
