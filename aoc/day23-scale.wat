;; Advent of Code's size shape, in wat: twenty thousand records, sorted and counted.
;;
;; Each line is a name and a score. Nothing here is clever; the puzzle is about SIZE, which is
;; the one thing the textbook suites never test and the reason NEXT.md put Advent of Code on the
;; list -- "is it pleasant for real work".
;;
;; Part one: the sum of the hundred highest scores.
;; Part two: how many distinct names appear.
;;
;; **Two container decisions, and this repository has already measured both.**
;;
;;   * The distinct names go into a `PersistentMap` to `true`, not a `HashMap`. F-057:
;;     `HashMap` copies on every insert and `PersistentMap` shares, and `probes/aoc/`'s two
;;     scaling probes put 4000 inserts at 341 ms against 40 ms. Twenty thousand of them is where
;;     that stops being a detail -- day05 spent 115 of its first 135 seconds on exactly this
;;     choice.
;;   * The scores are sorted whole and the top hundred taken off the end, because `sort` has no
;;     key and no comparator (day17) and no `take` that answers a Vector (F-088). Sorting twenty
;;     thousand to look at a hundred is wasteful and it is what the surface allows.
;;
;; The puzzle and its input are ours (aoc/input/day23-scale.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day23-scale.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day23-scale.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Seen (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool]))

(:wat::core::defn :aoc::scores [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::scores ls (:wat::core::+ i 1)
      (:wat::core::conj acc
        (:aoc::to-int (:wat::core::nth (:wat::string::split (:wat::core::nth ls i) " ") 1))))))

;; F-057: shares instead of copying, which at twenty thousand inserts is the whole runtime
(:wat::core::defn :aoc::names [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Seen] -> :aoc::Seen
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:aoc::names ls (:wat::core::+ i 1)
      (:wat::map::assoc acc (:wat::core::nth (:wat::string::split (:wat::core::nth ls i) " ") 0) true))))

;; the last `k` of an ascending sort, summed
(:wat::core::defn :aoc::top-sum [xs <- :aoc::Ints i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) acc
    (:aoc::top-sum xs (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth xs i)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [ls (:aoc::lines "aoc/input/day23-scale.txt")
     sorted (:wat::core::sort (:aoc::scores ls 0 (:wat::core::Vector :- [:wat::core::i64])))
     n (:wat::core::length sorted)
     seen (:aoc::names ls 0 (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool]))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day23-scale.expected"
                         "aoc day23 scale"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::top-sum sorted (:wat::core::- n 100) 0))
                           (int (:wat::core::length (:wat::map::keys seen)))))))
