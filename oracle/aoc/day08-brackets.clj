;; oracle/aoc/day08-brackets.clj: the reference implementation of our eighth puzzle, in Advent of
;; Code's shape — lines of brackets, checked with a stack.
;;
;; Part one: the syntax-error score. A line is CORRUPTED if a closing bracket does not match the
;; most recent unclosed opening one; each wrong closer scores 3, 57, 1197 or 25137 for ) ] } >.
;; Part two: the completion score. A line that is not corrupted is INCOMPLETE; close it, scoring
;; each closer added as score*5 + 1..4 for ) ] } >, and take the MEDIAN of those scores.
;;
;; The puzzle and its input are ours (aoc/input/day08-brackets.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def pairs {\( \) \[ \] \{ \} \< \>})
(def err {\) 3 \] 57 \} 1197 \> 25137})
(def fin {\) 1 \] 2 \} 3 \> 4})

(def lines (->> (slurp "aoc/input/day08-brackets.txt") str/split-lines (remove str/blank?)))

(defn scan [line]
  (loop [cs (seq line) stack ()]
    (if (empty? cs)
      [:incomplete stack]
      (let [c (first cs)]
        (if (contains? pairs c)
          (recur (rest cs) (conj stack c))
          (if (and (seq stack) (= c (pairs (first stack))))
            (recur (rest cs) (rest stack))
            [:corrupt c]))))))

(def results (map scan lines))

(def error-score
  (reduce + 0 (for [[k v] results :when (= k :corrupt)] (err v))))

(def completion-scores
  (sort (for [[k v] results :when (= k :incomplete)]
          (reduce (fn [acc c] (+ (* acc 5) (fin (pairs c)))) 0 v))))

(println "=>" error-score)
(println "=>" (nth completion-scores (quot (count completion-scores) 2)))
