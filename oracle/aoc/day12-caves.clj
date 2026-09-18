;; oracle/aoc/day12-caves.clj: the reference implementation of our twelfth puzzle, in Advent of
;; Code's shape — a cave system, and every path through it.
;;
;; Each line is an edge, `a-b`. A cave named in lower case is SMALL and may be visited once; a
;; cave named in upper case is BIG and may be visited any number of times. No two big caves are
;; joined, so the walk terminates.
;;
;; Part one: how many distinct paths run from `start` to `end`.
;; Part two: the same, except that ONE small cave on the path may be visited twice.
;;
;; The puzzle and its input are ours (aoc/input/day12-caves.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def edges
  (->> (slurp "aoc/input/day12-caves.txt") str/split-lines (remove str/blank?)
       (map #(str/split % #"-"))))

(def adj
  (reduce (fn [m [a b]] (-> m (update a (fnil conj []) b) (update b (fnil conj []) a)))
          {} edges))

(defn small? [s] (= s (str/lower-case s)))

(defn walk [twice? node seen used]
  (if (= node "end")
    1
    (reduce + 0
      (for [n (adj node) :when (not= n "start")]
        (cond
          (not (small? n))       (walk twice? n seen used)
          (not (seen n))         (walk twice? n (conj seen n) used)
          (and twice? (not used)) (walk twice? n seen true)
          :else 0)))))

(println "=>" (walk false "start" #{"start"} false))
(println "=>" (walk true  "start" #{"start"} false))
