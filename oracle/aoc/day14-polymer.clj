;; oracle/aoc/day14-polymer.clj: the reference implementation of our fourteenth puzzle, in Advent
;; of Code's shape — a polymer that grows between every pair.
;;
;; The input is a template, a blank line, then rules `AB -> C`: after a step, every adjacent pair
;; AB has a C inserted between them. The string doubles every step, so after 40 steps it is
;; astronomical and cannot be built — the answer is a count of PAIRS, not of characters.
;;
;; Part one: the commonest element's count minus the rarest's, after 10 steps.
;; Part two: the same after 40 steps.
;;
;; The puzzle and its input are ours (aoc/input/day14-polymer.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def blocks (str/split (slurp "aoc/input/day14-polymer.txt") #"\n\n"))
(def template (str/trim (first blocks)))

(def rules
  (into {} (for [l (remove str/blank? (str/split-lines (second blocks)))
                 :let [[a b] (str/split l #" -> ")]]
             [a b])))

(defn step [[pairs counts]]
  (reduce (fn [[p c] [pair n]]
            (let [m (rules pair)
                  l (str (subs pair 0 1) m)
                  r (str m (subs pair 1 2))]
              [(-> p (update l (fnil + 0) n) (update r (fnil + 0) n))
               (update c m (fnil + 0) n)]))
          [{} counts] pairs))

(defn after [n]
  (let [pairs (frequencies (map #(apply str %) (partition 2 1 template)))
        counts (frequencies (map str template))
        [_ c] (nth (iterate step [pairs counts]) n)]
    (- (apply max (vals c)) (apply min (vals c)))))

(println "=>" (after 10))
(println "=>" (after 40))
