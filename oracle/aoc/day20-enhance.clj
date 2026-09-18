;; oracle/aoc/day20-enhance.clj: the reference implementation of our twentieth puzzle, in Advent
;; of Code's shape — an image enhanced by a 512-entry lookup.
;;
;; The first line is the algorithm, 512 characters. The image follows after a blank line. Each
;; step replaces every pixel — INCLUDING the infinite border around the image — by reading its
;; 3x3 neighbourhood as a nine-bit index into the algorithm. Because entry 0 is lit here, the
;; infinite background flips on every step, which is the trap the puzzle is built around.
;;
;; Part one: lit pixels after 2 steps.
;; Part two: lit pixels after 12 steps.
;;
;; The puzzle and its input are ours (aoc/input/day20-enhance.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def blocks (str/split (str/trim (slurp "aoc/input/day20-enhance.txt")) #"\n\n"))
(def alg (str/trim (first blocks)))
(def image (vec (remove str/blank? (str/split-lines (second blocks)))))

(defn step [[grid bg]]
  (let [h (count grid) w (count (first grid))
        px (fn [r c] (if (and (>= r 0) (>= c 0) (< r h) (< c w))
                       (get-in grid [r c]) bg))
        out (vec (for [r (range -1 (inc h))]
                   (apply str (for [c (range -1 (inc w))]
                                (let [idx (reduce (fn [a [dr dc]]
                                                    (+ (* a 2) (if (= \# (px (+ r dr) (+ c dc))) 1 0)))
                                                  0 (for [dr [-1 0 1] dc [-1 0 1]] [dr dc]))]
                                  (nth alg idx))))))]
    [out (nth alg (if (= bg \.) 0 511))]))

(defn lit-after [n]
  (let [[g _] (nth (iterate step [image \.]) n)]
    (reduce + 0 (for [row g] (count (filter #(= \# %) row))))))

(println "=>" (lit-after 2))
(println "=>" (lit-after 12))
