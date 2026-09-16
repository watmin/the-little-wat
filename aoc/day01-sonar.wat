;; Advent of Code day one's shape, in wat: a file of depth readings, and two answers.
;;
;; Part one: how many readings are larger than the one before them.
;; Part two: the same, over the sums of every three consecutive readings.
;;
;; The puzzle and its input are ours (aoc/input/day01-sonar.txt, 2000 readings); Advent of
;; Code's own texts and inputs are not redistributable. The answers must be the reference
;; implementation's (oracle/aoc/day01-sonar.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day01-sonar.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :aoc::count-increases [xs <- :aoc::Ints i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs))
    acc
    (:aoc::count-increases xs (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::> (:wat::core::nth xs i) (:wat::core::nth xs (:wat::core::- i 1)))
        (:wat::core::+ acc 1)
        acc))))

(:wat::core::defn :aoc::sum [xs <- :aoc::Ints] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b)) 0 xs))

;; the sums of every three consecutive readings
(:wat::core::defn :aoc::window-sums [xs <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::mapv :aoc::sum (:wat::seq::window xs 3)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [depths (:aoc::ints "aoc/input/day01-sonar.txt")
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day01-sonar.expected"
                         "aoc day01 sonar"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::count-increases depths 1 0))
                           (int (:aoc::count-increases (:aoc::window-sums depths) 1 0))))))
