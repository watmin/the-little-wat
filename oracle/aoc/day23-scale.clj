;; oracle/aoc/day23-scale.clj: the reference implementation of our twenty-third puzzle, in Advent
;; of Code's shape — twenty thousand records, sorted and counted.
;;
;; Each line is a name and a score. Nothing here is clever; the puzzle is about SIZE, which is
;; the one thing the textbook suites never test.
;;
;; Part one: the sum of the hundred highest scores.
;; Part two: how many distinct names appear.
;;
;; The puzzle and its input are ours (aoc/input/day23-scale.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def rows
  (->> (slurp "aoc/input/day23-scale.txt") str/split-lines (remove str/blank?)
       (mapv (fn [l] (let [[n s] (str/split l #"\s+")] [n (Long/parseLong s)])))))

(println "=>" (reduce + 0 (take 100 (sort > (map second rows)))))
(println "=>" (count (set (map first rows))))
