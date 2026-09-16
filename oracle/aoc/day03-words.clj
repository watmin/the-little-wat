;; oracle/aoc/day03-words.clj: the reference implementation of our third puzzle, in Advent of
;; Code's shape — a file of words, counted.
;;
;; Part one: how many distinct words there are.
;; Part two: how often the most frequent word occurs.
;;
;; Both answers are independent of order, so nothing turns on how a map is iterated. The puzzle
;; and its input are ours (aoc/input/day03-words.txt); Advent of Code's own texts and inputs are
;; not redistributable. Run by tools/aoc-oracle.sh; every "=> " line is an answer the wat
;; solution must print too.

(require '[clojure.string :as str])

(def words
  (->> (slurp "aoc/input/day03-words.txt")
       str/split-lines
       (remove str/blank?)
       vec))

(def counts (frequencies words))

(println "=>" (count counts))
(println "=>" (apply max (vals counts)))
