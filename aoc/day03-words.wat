;; Advent of Code's counting shape, in wat: a file of words, and two answers.
;;
;; Part one: how many distinct words there are.
;; Part two: how often the most frequent word occurs.
;;
;; This one is about the hash map: 5000 words counted into one, then its keys read back. Both
;; answers are independent of order, so nothing turns on how the map is iterated. Every loop
;; here indexes with nth, because walking a Vector by rest copies it (F-055).
;;
;; The puzzle and its input are ours (aoc/input/day03-words.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day03-words.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day03-words.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Counts (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))

(:wat::core::defn :aoc::count-word [counts <- :aoc::Counts w <- :wat::core::String] -> :aoc::Counts
  (:wat::core::match (:wat::hashmap::get counts w)
    [:wat::core::Option.Some {:value n} (:wat::hashmap::assoc counts w (:wat::core::+ n 1))]
    [:wat::core::Option.None {} (:wat::hashmap::assoc counts w 1)]))

(:wat::core::defn :aoc::count-all [ws <- :aoc::Lines i <- :wat::core::i64 counts <- :aoc::Counts] -> :aoc::Counts
  (:wat::core::if (:wat::core::>= i (:wat::core::length ws))
    counts
    (:aoc::count-all ws (:wat::core::+ i 1) (:aoc::count-word counts (:wat::core::nth ws i)))))

(:wat::core::defn :aoc::highest [counts <- :aoc::Counts keys <- :aoc::Lines i <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length keys))
    best
    (:wat::core::let [n (:wat::core::match (:wat::hashmap::get counts (:wat::core::nth keys i))
                          [:wat::core::Option.Some {:value v} v]
                          [:wat::core::Option.None {} 0])]
      (:aoc::highest counts keys (:wat::core::+ i 1) (:wat::core::if (:wat::core::> n best) n best)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [words (:aoc::lines "aoc/input/day03-words.txt")
                    counts (:aoc::count-all words 0 (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
                    keys (:wat::hashmap::keys counts)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day03-words.expected"
                         "aoc day03 words"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:wat::core::length keys))
                           (int (:aoc::highest counts keys 0 0))))))
