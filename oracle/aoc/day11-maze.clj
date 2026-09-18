;; oracle/aoc/day11-maze.clj: the reference implementation of our eleventh puzzle, in Advent of
;; Code's shape — a maze, walked breadth-first.
;;
;; Part one: the fewest steps from the top-left corner to the bottom-right one, moving up, down,
;; left and right through open squares.
;; Part two: how many squares are reachable from the corner at all.
;;
;; The puzzle and its input are ours (aoc/input/day11-maze.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def grid (->> (slurp "aoc/input/day11-maze.txt") str/split-lines (remove str/blank?) vec))
(def h (count grid))
(def w (count (first grid)))
(defn open? [r c] (and (>= r 0) (>= c 0) (< r h) (< c w) (= \. (get-in grid [r c]))))

;; breadth-first BY LEVEL: the whole frontier is stepped at once, which is how the wat solution
;; does it too
(def levels
  (loop [frontier #{[0 0]} seen #{[0 0]} d 0 out {[0 0] 0}]
    (if (empty? frontier)
      out
      (let [nxt (set (for [[r c] frontier
                           [dr dc] [[1 0] [-1 0] [0 1] [0 -1]]
                           :let [x (+ r dr) y (+ c dc)]
                           :when (and (open? x y) (not (seen [x y])))]
                       [x y]))]
        (recur nxt (into seen nxt) (inc d)
               (into out (for [p nxt] [p (inc d)])))))))

(println "=>" (get levels [(dec h) (dec w)]))
(println "=>" (count levels))
