;; oracle/aoc/day06-adapters.clj: the reference implementation for aoc/day06-adapters.wat.
;;
;; The puzzle is ours, in Advent of Code's shape. A bag of adapters, each with a rating; they
;; chain from a 0-rated outlet up to a device rated three above the largest, and an adapter can
;; follow another whose rating is 1, 2 or 3 lower.
;;
;; Part one: sort them all into one chain and multiply the number of 1-steps by the number of
;; 3-steps.
;; Part two: count the DISTINCT arrangements that still connect the outlet to the device.
;;
;; Part two is the point. The answer is over 1.7e17, so nothing can enumerate the arrangements;
;; the count has to be built from the counts of the shorter chains. That is the whole reason the
;; wat port cares -- see P-028.
;;
;; Run by tools/aoc-oracle.sh with the clojure CLI; every "=> " line is an expected answer.

(def ratings (->> (slurp "aoc/input/day06-adapters.txt")
                  clojure.string/split-lines
                  (remove clojure.string/blank?)
                  (map #(Long/parseLong (clojure.string/trim %)))
                  sort
                  vec))

(def chain (vec (concat [0] ratings [(+ 3 (peek ratings))])))

(defn show [v] (println (str "=> " v)))

;; --- part one: the gaps ---
(def gaps (map - (rest chain) chain))
(def d1 (count (filter #(= 1 %) gaps)))
(def d3 (count (filter #(= 3 %) gaps)))

(show (count ratings))
(show d1)
(show d3)
(show (* d1 d3))

;; --- part two: the arrangements, counted rather than enumerated ---
(def ways
  (reduce (fn [acc v]
            (assoc acc v (+ (get acc (- v 1) 0) (get acc (- v 2) 0) (get acc (- v 3) 0))))
          {0 1}
          (rest chain)))

(show (get ways (peek chain)))
;; the count is far past anything that could be listed: every arrangement would need a nanosecond
(show (> (get ways (peek chain)) 1e17))
;; and the chain itself is only 97 links long, which is the gap the memo closes
(show (count chain))
