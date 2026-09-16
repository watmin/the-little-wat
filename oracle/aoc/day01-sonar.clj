;; oracle/aoc/day01-sonar.clj: the reference implementation of our first puzzle, in Advent of
;; Code's shape — a file of depth readings, and two answers from it.
;;
;; Part one: how many readings are larger than the one before them.
;; Part two: the same, over the sums of every three consecutive readings.
;;
;; The puzzle and its input are ours (aoc/input/day01-sonar.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh; every "=> " line is an answer the
;; wat solution must print too.

(require '[clojure.string :as str])

(def depths
  (->> (slurp "aoc/input/day01-sonar.txt")
       str/split-lines
       (remove str/blank?)
       (map parse-long)
       vec))

(defn increases [xs]
  (count (filter true? (map < xs (rest xs)))))

(println "=>" (increases depths))
(println "=>" (increases (map + depths (rest depths) (rest (rest depths)))))
