;; oracle/aoc/day24-order.clj: the reference implementation of our twenty-fourth puzzle, in
;; Advent of Code's shape — jobs with dependencies, put in order.
;;
;; Each line says `a before b`. Every job named anywhere must be done, and a job may only start
;; once everything that must come before it is finished.
;;
;; Part one: the order, choosing the alphabetically first job whenever several are ready — one
;; answer, as a comma-separated string.
;; Part two: the length of the longest chain of dependencies, counted in jobs.
;;
;; The puzzle and its input are ours (aoc/input/day24-order.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def edges
  (for [l (->> (slurp "aoc/input/day24-order.txt") str/split-lines (remove str/blank?))
        :let [[a _ b] (str/split l #"\s+")]]
    [a b]))

(def jobs (sort (set (concat (map first edges) (map second edges)))))
(def after (reduce (fn [m [a b]] (update m a (fnil conj #{}) b)) {} edges))
(def indeg (reduce (fn [m [_ b]] (update m b (fnil inc 0))) (zipmap jobs (repeat 0)) edges))

(def ordered
  (loop [ind indeg done []]
    (if (= (count done) (count jobs))
      done
      (let [n (first (sort (for [j jobs :when (and (zero? (ind j 0)) (not (some #{j} done)))] j)))]
        (recur (reduce (fn [m k] (update m k dec)) (assoc ind n -1) (after n [])) (conj done n))))))

(def depth
  (memoize (fn [n] (inc (reduce max 0 (map #(depth %) (after n [])))))))

(println "=>" (str/join "," ordered))
(println "=>" (reduce max 0 (map depth jobs)))
