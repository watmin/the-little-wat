;; oracle/aoc/day15-bingo.clj: the reference implementation of our fifteenth puzzle, in Advent of
;; Code's shape — bingo boards, marked as numbers are drawn.
;;
;; The input is a draw order, a blank line, then 5x5 boards separated by blank lines. A board
;; wins when a whole row or a whole column is marked; its score is the sum of its unmarked
;; numbers times the number just drawn.
;;
;; Part one: the score of the FIRST board to win.
;; Part two: the score of the LAST.
;;
;; The puzzle and its input are ours (aoc/input/day15-bingo.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def blocks (str/split (str/trim (slurp "aoc/input/day15-bingo.txt")) #"\n\n"))
(def draws (map #(Long/parseLong %) (str/split (str/trim (first blocks)) #",")))
(def boards
  (for [b (rest blocks)]
    (vec (map #(Long/parseLong %) (str/split (str/trim b) #"\s+")))))

(defn wins? [marks]
  (or (some (fn [r] (every? #(marks (+ (* r 5) %)) (range 5))) (range 5))
      (some (fn [c] (every? #(marks (+ (* % 5) c)) (range 5))) (range 5))))

(def scores
  (loop [ds draws marks (vec (repeat (count boards) #{})) done #{} out []]
    (if (empty? ds)
      out
      (let [d (first ds)
            marks' (vec (for [[i b] (map-indexed vector boards)]
                          (into (marks i) (for [j (range 25) :when (= d (b j))] j))))
            newly (for [i (range (count boards))
                        :when (and (not (done i)) (wins? (marks' i)))]
                    i)
            out' (into out (for [i newly]
                             (* d (reduce + 0 (for [j (range 25)
                                                    :when (not ((marks' i) j))]
                                                ((nth boards i) j))))))]
        (recur (rest ds) marks' (into done newly) out')))))

(println "=>" (first scores))
(println "=>" (last scores))
