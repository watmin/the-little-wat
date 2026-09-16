;; Advent of Code day nine's shape, in wat: a grid of heights, 100 by 100, and two answers.
;;
;; Part one: the sum of 1 + height over every point lower than all four of its neighbours.
;; Part two: how many points are lower than the point to their left.
;;
;; The grid is the test: wat has no character access, so each row's digits are read with a
;; one-character substring per column (10000 of them), and the grid is a Vector of Vectors.
;;
;; The puzzle and its input are ours (aoc/input/day02-smoke.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day02-smoke.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day02-smoke.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Grid (:wat::core::Vector :- [(:wat::core::Vector :- [:wat::core::i64])]))

;; a row of digits: one character at a time, since a String has no elements
(:wat::core::defn :aoc::digits-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:aoc::digits-from s (:wat::core::+ i 1) n
      (:wat::core::conj acc (:aoc::to-int (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :aoc::digits [s <- :wat::core::String] -> :aoc::Ints
  (:aoc::digits-from s 0 (:wat::string::length s) (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :aoc::grid [path <- :wat::core::String] -> :aoc::Grid
  (:wat::core::mapv :aoc::digits (:aoc::lines path)))

(:wat::core::defn :aoc::at [g <- :aoc::Grid y <- :wat::core::i64 x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::nth (:wat::core::nth g y) x))

;; is the point lower than each of its four neighbours? (an edge has fewer)
(:wat::core::defn :aoc::low-point? [g <- :aoc::Grid y <- :wat::core::i64 x <- :wat::core::i64 h <- :wat::core::i64 w <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::let [v (:aoc::at g y x)]
    (:wat::core::and
      (:wat::core::or (:wat::core::= y 0) (:wat::core::< v (:aoc::at g (:wat::core::- y 1) x)))
      (:wat::core::and
        (:wat::core::or (:wat::core::= y (:wat::core::- h 1)) (:wat::core::< v (:aoc::at g (:wat::core::+ y 1) x)))
        (:wat::core::and
          (:wat::core::or (:wat::core::= x 0) (:wat::core::< v (:aoc::at g y (:wat::core::- x 1))))
          (:wat::core::or (:wat::core::= x (:wat::core::- w 1)) (:wat::core::< v (:aoc::at g y (:wat::core::+ x 1)))))))))

(:wat::core::defn :aoc::risk-row [g <- :aoc::Grid y <- :wat::core::i64 x <- :wat::core::i64 h <- :wat::core::i64 w <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= x w)
    acc
    (:aoc::risk-row g y (:wat::core::+ x 1) h w
      (:wat::core::if (:aoc::low-point? g y x h w)
        (:wat::core::+ acc (:wat::core::+ 1 (:aoc::at g y x)))
        acc))))

(:wat::core::defn :aoc::risk [g <- :aoc::Grid y <- :wat::core::i64 h <- :wat::core::i64 w <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= y h)
    acc
    (:aoc::risk g (:wat::core::+ y 1) h w (:aoc::risk-row g y 0 h w acc))))

(:wat::core::defn :aoc::downhill-row [g <- :aoc::Grid y <- :wat::core::i64 x <- :wat::core::i64 w <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= x w)
    acc
    (:aoc::downhill-row g y (:wat::core::+ x 1) w
      (:wat::core::if (:wat::core::< (:aoc::at g y x) (:aoc::at g y (:wat::core::- x 1)))
        (:wat::core::+ acc 1)
        acc))))

(:wat::core::defn :aoc::downhill [g <- :aoc::Grid y <- :wat::core::i64 h <- :wat::core::i64 w <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= y h)
    acc
    (:aoc::downhill g (:wat::core::+ y 1) h w (:aoc::downhill-row g y 1 w acc))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [g (:aoc::grid "aoc/input/day02-smoke.txt")
                    h (:wat::core::length g)
                    w (:wat::core::length (:wat::core::first g))
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day02-smoke.expected"
                         "aoc day02 smoke"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::risk g 0 h w 0))
                           (int (:aoc::downhill g 0 h w 0))))))
