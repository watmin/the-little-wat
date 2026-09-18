;; oracle/aoc/day13-origami.clj: the reference implementation of our thirteenth puzzle, in Advent
;; of Code's shape — a sheet of dots, folded.
;;
;; The input is a list of `x,y` dots, a blank line, then fold instructions. A fold along `y=v`
;; reflects every dot below the line upwards; a fold along `x=v` reflects every dot to the right
;; of it leftwards. Dots that land on each other merge.
;;
;; Part one: how many dots are left after the FIRST fold.
;; Part two: the picture after ALL the folds, one answer per row — so the answers are text.
;;
;; The puzzle and its input are ours (aoc/input/day13-origami.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def blocks (str/split (slurp "aoc/input/day13-origami.txt") #"\n\n"))

(def dots
  (set (for [l (remove str/blank? (str/split-lines (first blocks)))
             :let [[a b] (str/split l #",")]]
         [(Long/parseLong a) (Long/parseLong b)])))

(def folds
  (for [l (remove str/blank? (str/split-lines (second blocks)))
        :let [[_ axis v] (re-matches #"fold along ([xy])=(\d+)" l)]]
    [axis (Long/parseLong v)]))

(defn fold [s [axis v]]
  (set (for [[x y] s]
         (if (= axis "y")
           [x (if (> y v) (- (* 2 v) y) y)]
           [(if (> x v) (- (* 2 v) x) x) y]))))

(def after-first (fold dots (first folds)))
(def final (reduce fold dots folds))

(def w (inc (apply max (map first final))))
(def h (inc (apply max (map second final))))

(println "=>" (count after-first))
(doseq [y (range h)]
  (println "=>" (apply str (for [x (range w)] (if (final [x y]) \# \.)))))
