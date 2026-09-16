;; oracle/aoc/day05-paths.clj: the reference implementation of our fifth puzzle, in Advent of
;; Code's shape — a grid of risk levels, and the cheapest way across it.
;;
;; Part one: the lowest total risk of any path from the top-left corner to the bottom-right,
;; moving up, down, left or right, counting every square entered.
;; Part two: the same on the grid five times as wide and five times as tall, where each copy's
;; risks are one higher than the copy above and to the left, wrapping from 9 back to 1.
;;
;; Clojure says this with a sorted set as the frontier — a priority queue, which is how
;; Dijkstra's algorithm is meant to be written. The puzzle and its input are ours
;; (aoc/input/day05-paths.txt); Advent of Code's own texts and inputs are not redistributable.
;; Run by tools/aoc-oracle.sh; every "=> " line is an answer the wat solution must print too.

(require '[clojure.string :as str])

(def base
  (->> (slurp "aoc/input/day05-paths.txt")
       str/split-lines
       (remove str/blank?)
       (mapv (fn [line] (mapv #(- (int %) (int \0)) line)))))

(defn grown [g times]
  (let [h (count g) w (count (first g))]
    (vec (for [y (range (* times h))]
           (vec (for [x (range (* times w))]
                  (let [bump (+ (quot y h) (quot x w))
                        v (+ (get-in g [(mod y h) (mod x w)]) bump)]
                    (inc (mod (dec v) 9)))))))))

(defn cheapest [g]
  (let [h (count g) w (count (first g))
        goal [(dec h) (dec w)]]
    (loop [frontier (sorted-set [0 [0 0]])
           seen #{}]
      (let [[cost pos :as top] (first frontier)
            rest-frontier (disj frontier top)]
        (cond
          (= pos goal) cost
          (seen pos) (recur rest-frontier seen)
          :else
          (let [[y x] pos
                nexts (for [[dy dx] [[-1 0] [1 0] [0 -1] [0 1]]
                            :let [ny (+ y dy) nx (+ x dx)]
                            :when (and (< -1 ny h) (< -1 nx w) (not (seen [ny nx])))]
                        [(+ cost (get-in g [ny nx])) [ny nx]])]
            (recur (into rest-frontier nexts) (conj seen pos))))))))

(println "=>" (cheapest base))
(println "=>" (cheapest (grown base 5)))
