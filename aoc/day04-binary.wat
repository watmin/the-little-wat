;; Advent of Code's binary shape, in wat: a file of binary numbers read column by column.
;;
;; Part one: the most common bit in each column makes one number, the least common makes
;; another; the answer is their product.
;; Part two: keep the rows whose bit in a column is the most common among the rows left (ties
;; keep 1) until one remains, and the same keeping the least common (ties keep 0); the answer is
;; the product of the two.
;;
;; The puzzle is written with bit operations everywhere else: the Clojure reference uses
;; bit-xor and a shift for the complement. wat has none — no and, or, xor, not or shift on
;; integers (F-035) — so every bit here is arithmetic: a number is built by doubling and
;; adding, and the complement is (2^width - 1) minus the number, with 2^width reached by
;; doubling. A column's bit is a one-character substring, since a String has no elements.
;;
;; The puzzle and its input are ours (aoc/input/day04-binary.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day04-binary.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day04-binary.wat

(:wat::load-file! "lib/check.wat")

;; the bit in column i of a row, as 0 or 1
(:wat::core::defn :aoc::bit-at [row <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:wat::string::subs row i (:wat::core::+ i 1)) "1") 1 0))

;; how many rows have a 1 in column i
(:wat::core::defn :aoc::ones-at [rows <- :aoc::Lines i <- :wat::core::i64 j <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= j (:wat::core::length rows))
    acc
    (:aoc::ones-at rows i (:wat::core::+ j 1) (:wat::core::+ acc (:aoc::bit-at (:wat::core::nth rows j) i)))))

;; a binary string as a number: doubling and adding, since there is no shift
(:wat::core::defn :aoc::binary-value [row <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:aoc::binary-value row (:wat::core::+ i 1) n (:wat::core::+ (:wat::core::* 2 acc) (:aoc::bit-at row i)))))

;; the most common bit of each column, as one number
(:wat::core::defn :aoc::gamma [rows <- :aoc::Lines i <- :wat::core::i64 width <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i width)
    acc
    (:wat::core::let [ones (:aoc::ones-at rows i 0 0)
                      bit (:wat::core::if (:wat::core::>= (:wat::core::* 2 ones) (:wat::core::length rows)) 1 0)]
      (:aoc::gamma rows (:wat::core::+ i 1) width (:wat::core::+ (:wat::core::* 2 acc) bit)))))

;; 2^n, by doubling: there is no shift either
(:wat::core::defn :aoc::two-to [n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) acc (:aoc::two-to (:wat::core::- n 1) (:wat::core::* 2 acc))))

;; the rows whose bit in column i is the one wanted
(:wat::core::defn :aoc::keep-bit [rows <- :aoc::Lines i <- :wat::core::i64 want <- :wat::core::i64] -> :aoc::Lines
  (:wat::core::filterv (:wat::core::fn [row <- :wat::core::String] -> :wat::core::bool (:wat::core::= (:aoc::bit-at row i) want)) rows))

;; narrow to one row: most? keeps the most common bit of the column (ties keep 1), otherwise the
;; least common (ties keep 0)
(:wat::core::defn :aoc::narrow [rows <- :aoc::Lines i <- :wat::core::i64 width <- :wat::core::i64 most? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if (:wat::core::or (:wat::core::= (:wat::core::length rows) 1) (:wat::core::>= i width))
    (:wat::core::first rows)
    (:wat::core::let [ones (:aoc::ones-at rows i 0 0)
                      zeros (:wat::core::- (:wat::core::length rows) ones)
                      want (:wat::core::if most?
                             (:wat::core::if (:wat::core::>= ones zeros) 1 0)
                             (:wat::core::if (:wat::core::<= zeros ones) 0 1))]
      (:aoc::narrow (:aoc::keep-bit rows i want) (:wat::core::+ i 1) width most?))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [rows (:aoc::lines "aoc/input/day04-binary.txt")
                    width (:wat::string::length (:wat::core::first rows))
                    g (:aoc::gamma rows 0 width 0)
                    ;; the complement, without a xor: all ones, minus gamma
                    e (:wat::core::- (:wat::core::- (:aoc::two-to width 1) 1) g)
                    oxygen (:aoc::binary-value (:aoc::narrow rows 0 width true) 0 width 0)
                    co2 (:aoc::binary-value (:aoc::narrow rows 0 width false) 0 width 0)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day04-binary.expected"
                         "aoc day04 binary"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:wat::core::* g e))
                           (int (:wat::core::* oxygen co2))))))
