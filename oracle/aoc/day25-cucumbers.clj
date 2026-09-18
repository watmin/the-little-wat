;; oracle/aoc/day25-cucumbers.clj: the reference implementation of our twenty-fifth puzzle, in
;; Advent of Code's shape — two herds shuffling until they jam.
;;
;; `>` moves one square east, `v` one square south, and both wrap around the edges. Every east
;; mover that can move does so at the same instant; then every south mover that can. A square is
;; free only if it is free at the moment that herd moves.
;;
;; The answer: the number of the first step on which nothing moves at all. Advent of Code's
;; twenty-fifth day has one part, so this puzzle has one answer.
;;
;; The puzzle and its input are ours (aoc/input/day25-cucumbers.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def start (vec (->> (slurp "aoc/input/day25-cucumbers.txt") str/split-lines (remove str/blank?))))
(def h (count start))
(def w (count (first start)))

(defn move [grid who dr dc]
  (let [at (fn [r c] (get-in grid [(mod r h) (mod c w)]))]
    (vec (for [r (range h)]
           (apply str (for [c (range w)]
                        (let [here (at r c)
                              from (at (- r dr) (- c dc))
                              to   (at (+ r dr) (+ c dc))]
                          (cond
                            (and (= here who) (= to \.)) \.
                            (and (= here \.) (= from who)) who
                            :else here))))))))

(def answer
  (loop [g start n 1]
    (let [g' (-> g (move \> 0 1) (move \v 1 0))]
      (if (= g' g) n (recur g' (inc n))))))

(println "=>" answer)
