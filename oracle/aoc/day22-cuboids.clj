;; oracle/aoc/day22-cuboids.clj: the reference implementation of our twenty-second puzzle, in
;; Advent of Code's shape — overlapping boxes switched on and off.
;;
;; Each line turns a box of cubes on or off. The boxes overlap and the space is far too large to
;; hold a cube per coordinate, so the count is kept by INCLUSION AND EXCLUSION: every new box is
;; intersected with each signed box already recorded, and the intersection is recorded with the
;; opposite sign. The total is the signed sum of the volumes.
;;
;; Part one: how many cubes are on, counting only the instructions that lie entirely within
;; -50..50 on every axis.
;; Part two: how many are on, counting every instruction.
;;
;; The puzzle and its input are ours (aoc/input/day22-cuboids.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def steps
  (for [l (->> (slurp "aoc/input/day22-cuboids.txt") str/split-lines (remove str/blank?))
        :let [[_ op a b c d e f] (re-matches #"(on|off) x=(-?\d+)\.\.(-?\d+),y=(-?\d+)\.\.(-?\d+),z=(-?\d+)\.\.(-?\d+)" l)]]
    (into [(= op "on")] (map #(Long/parseLong %) [a b c d e f]))))

(defn apply-step [cubes [on x1 x2 y1 y2 z1 z2]]
  (let [overlaps (for [[s a b c d e f] cubes
                       :let [ia (max a x1) ib (min b x2)
                             ic (max c y1) id (min d y2)
                             ie (max e z1) if- (min f z2)]
                       :when (and (<= ia ib) (<= ic id) (<= ie if-))]
                   [(- s) ia ib ic id ie if-])]
    (into cubes (if on (conj (vec overlaps) [1 x1 x2 y1 y2 z1 z2]) overlaps))))

(defn total [cubes]
  (reduce + 0 (for [[s a b c d e f] cubes]
                (* s (inc (- b a)) (inc (- d c)) (inc (- f e))))))

(defn small? [[_ a b c d e f]] (every? #(<= -50 % 50) [a b c d e f]))

(println "=>" (total (reduce apply-step [] (filter small? steps))))
(println "=>" (total (reduce apply-step [] steps)))
