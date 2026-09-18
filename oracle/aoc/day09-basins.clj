;; oracle/aoc/day09-basins.clj: the reference implementation of our ninth puzzle, in Advent of
;; Code's shape — a grid of heights, and the basins the 9s divide it into.
;;
;; Part one: how many basins there are. A basin is a maximal region of cells below 9, joined
;; up, down, left and right.
;; Part two: the product of the three largest basins' sizes.
;;
;; The puzzle and its input are ours (aoc/input/day09-basins.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def grid
  (->> (slurp "aoc/input/day09-basins.txt") str/split-lines (remove str/blank?)
       (mapv (fn [l] (mapv #(- (int %) (int \0)) l)))))

(def h (count grid))
(def w (count (first grid)))
(defn at [r c] (get-in grid [r c]))

(defn flood [seen r c]
  ;; iterative, so the reference does not depend on the host's stack either
  (loop [stack [[r c]] seen seen n 0]
    (if (empty? stack)
      [seen n]
      (let [[a b] (peek stack) rest-stack (pop stack)]
        (if (or (< a 0) (< b 0) (>= a h) (>= b w) (seen [a b]) (= 9 (at a b)))
          (recur rest-stack seen n)
          (recur (into rest-stack [[(inc a) b] [(dec a) b] [a (inc b)] [a (dec b)]])
                 (conj seen [a b]) (inc n)))))))

(def sizes
  (loop [cells (for [r (range h) c (range w)] [r c]) seen #{} out []]
    (if (empty? cells)
      out
      (let [[r c] (first cells)]
        (if (or (seen [r c]) (= 9 (at r c)))
          (recur (rest cells) seen out)
          (let [[seen' n] (flood seen r c)]
            (recur (rest cells) seen' (conj out n))))))))

(def top3 (take 3 (sort > sizes)))

(println "=>" (count sizes))
(println "=>" (reduce * 1 top3))
