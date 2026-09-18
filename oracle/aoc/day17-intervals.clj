;; oracle/aoc/day17-intervals.clj: the reference implementation of our seventeenth puzzle, in
;; Advent of Code's shape — blocked ranges over a large space.
;;
;; Each line is an inclusive range `lo-hi` of blocked values, over 0 to 999999999. The ranges
;; overlap and are given in no order.
;;
;; Part one: the lowest value that is not blocked.
;; Part two: how many values are not blocked.
;;
;; The puzzle and its input are ours (aoc/input/day17-intervals.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def limit 999999999)

(def ranges
  (->> (slurp "aoc/input/day17-intervals.txt") str/split-lines (remove str/blank?)
       (map (fn [l] (let [[a b] (str/split l #"-")]
                      [(Long/parseLong a) (Long/parseLong b)])))
       (sort-by first)))

(def scan
  (reduce (fn [{:keys [cur lowest allowed]} [lo hi]]
            (let [gap (max 0 (- lo cur))]
              {:cur (max cur (inc hi))
               :lowest (if (and (nil? lowest) (pos? gap)) cur lowest)
               :allowed (+ allowed gap)}))
          {:cur 0 :lowest nil :allowed 0} ranges))

(def tail (max 0 (- (inc limit) (:cur scan))))

(println "=>" (if (:lowest scan) (:lowest scan) (:cur scan)))
(println "=>" (+ (:allowed scan) tail))
