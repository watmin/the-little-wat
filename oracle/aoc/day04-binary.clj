;; oracle/aoc/day04-binary.clj: the reference implementation of our fourth puzzle, in Advent of
;; Code's shape — a file of binary numbers, read column by column.
;;
;; Part one: the most common bit in each column makes one number, the least common makes
;; another; the answer is their product.
;; Part two: keep the rows whose bit in each column is the most common among the rows left
;; (ties keep 1) until one row remains, and the same keeping the least common (ties keep 0);
;; the answer is the product of the two.
;;
;; Clojure says this with bit operations, which is how the puzzle is meant to be written. The
;; puzzle and its input are ours (aoc/input/day04-binary.txt); Advent of Code's own texts and
;; inputs are not redistributable. Run by tools/aoc-oracle.sh; every "=> " line is an answer the
;; wat solution must print too.

(require '[clojure.string :as str])

(def rows
  (->> (slurp "aoc/input/day04-binary.txt")
       str/split-lines
       (remove str/blank?)
       vec))

(def width (count (first rows)))

(defn ones-at [rs i] (count (filter #(= \1 (nth % i)) rs)))

(def gamma
  (Long/parseLong (apply str (for [i (range width)]
                               (if (>= (* 2 (ones-at rows i)) (count rows)) \1 \0)))
                  2))

(def epsilon (bit-xor gamma (dec (bit-shift-left 1 width))))

(println "=>" (* gamma epsilon))

(defn narrow [rs most?]
  (loop [rs rs i 0]
    (if (or (= 1 (count rs)) (= i width))
      (first rs)
      (let [ones (ones-at rs i)
            zeros (- (count rs) ones)
            want (if most?
                   (if (>= ones zeros) \1 \0)
                   (if (<= zeros ones) \0 \1))]
        (recur (filterv #(= want (nth % i)) rs) (inc i))))))

(println "=>" (* (Long/parseLong (narrow rows true) 2)
                 (Long/parseLong (narrow rows false) 2)))
