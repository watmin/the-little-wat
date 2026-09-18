;; oracle/aoc/day10-growth.clj: the reference implementation of our tenth puzzle, in Advent of
;; Code's shape — a population that doubles on a timer.
;;
;; Each number is a timer. Every day every timer drops by one; a timer at 0 becomes 6 and adds a
;; new timer at 8. The population is exponential, so the list cannot be simulated — the answer is
;; nine counters, one per timer value, rotated once a day.
;;
;; Part one: the population after 80 days.
;; Part two: the population after 500 days — which does not fit in 64 bits, and is the point.
;;
;; The puzzle and its input are ours (aoc/input/day10-growth.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def timers
  (->> (str/split (str/trim (slurp "aoc/input/day10-growth.txt")) #",")
       (map #(Long/parseLong %))))

(def start (vec (for [i (range 9)] (bigint (count (filter #(= i %) timers))))))

(defn step [b]
  (let [z (nth b 0)]
    (-> (vec (concat (subvec b 1) [0N]))
        (update 6 + z)
        (assoc 8 z))))

(defn after [n] (reduce + 0N (nth (iterate step start) n)))

;; `(println 2671243415848383689686N)` prints a trailing N in Clojure too, and an answer is a
;; number, so both are printed as plain digits.
(println "=>" (str (biginteger (after 80))))
(println "=>" (str (biginteger (after 500))))
