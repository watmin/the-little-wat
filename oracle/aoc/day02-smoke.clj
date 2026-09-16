;; oracle/aoc/day02-smoke.clj: the reference implementation of our second puzzle, in Advent of
;; Code's shape — a grid of heights, 100 by 100.
;;
;; Part one: the sum of 1 + height over every point lower than all four of its neighbours.
;; Part two: how many points are lower than the point to their left, counted row by row —
;; a second pass over the same grid, by index.
;;
;; The puzzle and its input are ours (aoc/input/day02-smoke.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh; every "=> " line is an answer the
;; wat solution must print too.

(require '[clojure.string :as str])

(def rows
  (->> (slurp "aoc/input/day02-smoke.txt")
       str/split-lines
       (remove str/blank?)
       (mapv (fn [line] (mapv #(- (int %) (int \0)) line)))))

(def height (count rows))
(def width (count (first rows)))

(defn at [y x] (get-in rows [y x]))

(defn low-point? [y x]
  (let [h (at y x)]
    (every? (fn [[dy dx]]
              (let [ny (+ y dy) nx (+ x dx)]
                (or (neg? ny) (neg? nx) (>= ny height) (>= nx width) (< h (at ny nx)))))
            [[-1 0] [1 0] [0 -1] [0 1]])))

(def risk
  (reduce + (for [y (range height) x (range width) :when (low-point? y x)] (inc (at y x)))))

(def downhill-steps
  (count (for [y (range height) x (range 1 width) :when (< (at y x) (at y (dec x)))] 1)))

(println "=>" risk)
(println "=>" downhill-steps)
