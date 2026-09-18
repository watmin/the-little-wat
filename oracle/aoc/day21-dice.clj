;; oracle/aoc/day21-dice.clj: the reference implementation of our twenty-first puzzle, in Advent
;; of Code's shape — a board game played two ways.
;;
;; Two players move around a ten-square track; landing on a square adds its number to the score.
;;
;; Part one: a deterministic die, rolled three times a turn, cycling 1 to 100. Play to 1000 and
;; answer the loser's score times the number of rolls.
;; Part two: a three-sided die that splits the universe on every roll — 27 futures a turn, 7
;; distinct sums. Play to 21, and answer how many universes the more successful player wins in.
;; Only memoisation makes that finite: there are 16172 reachable states.
;;
;; The puzzle and its input are ours (aoc/input/day21-dice.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def starts
  (->> (slurp "aoc/input/day21-dice.txt") str/split-lines (remove str/blank?)
       (mapv (fn [l] (Long/parseLong (last (str/split l #" ")))))))

(defn deterministic []
  (loop [pos (vec starts) score [0 0] die 0 rolls 0 turn 0]
    (let [[d s] (reduce (fn [[d s] _] (let [d' (inc (mod d 100))] [d' (+ s d')])) [die 0] (range 3))
          p (inc (mod (+ (dec (pos turn)) s) 10))
          sc (+ (score turn) p)]
      (if (>= sc 1000)
        (* (score (- 1 turn)) (+ rolls 3))
        (recur (assoc pos turn p) (assoc score turn sc) d (+ rolls 3) (- 1 turn))))))

(def freq (frequencies (for [a [1 2 3] b [1 2 3] c [1 2 3]] (+ a b c))))

(def quantum
  (memoize
    (fn [pa sa pb sb]
      (reduce (fn [[a b] [s n]]
                (let [np (inc (mod (+ (dec pa) s) 10))
                      ns (+ sa np)]
                  (if (>= ns 21)
                    [(+ a (* n 1)) b]
                    (let [[wb wa] (quantum pb sb np ns)]
                      [(+ a (* n wa)) (+ b (* n wb))]))))
              [0 0] freq))))

(println "=>" (deterministic))
(println "=>" (apply max (quantum (starts 0) 0 (starts 1) 0)))
