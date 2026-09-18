;; oracle/aoc/day18-snailfish.clj: the reference implementation of our eighteenth puzzle, in
;; Advent of Code's shape — nested pairs that reduce as they are added.
;;
;; A number is a pair, and each side is a number or a digit. Adding two makes a new pair, which
;; is then REDUCED: while any pair sits deeper than four, the leftmost such pair EXPLODES (its
;; left value adds to the nearest value on its left, its right to the nearest on its right, and
;; the pair becomes 0); otherwise, while any value is 10 or more, the leftmost SPLITS into two
;; halves, rounded down then up. The magnitude of a pair is 3 × left + 2 × right.
;;
;; Both implementations keep the number as a flat list of (value, depth), which is what makes
;; "the nearest value on the left" a neighbouring element rather than a tree walk.
;;
;; Part one: the magnitude of the sum of every number, in order.
;; Part two: the largest magnitude of any two different numbers added.
;;
;; The puzzle and its input are ours (aoc/input/day18-snailfish.txt); Advent of Code's own texts
;; and inputs are not redistributable. Run by tools/aoc-oracle.sh.

(require '[clojure.string :as str])

(def lines (->> (slurp "aoc/input/day18-snailfish.txt") str/split-lines (remove str/blank?)))

(defn flatten-num [s]
  (loop [cs (seq s) d 0 out []]
    (if (empty? cs)
      out
      (let [c (first cs)]
        (cond
          (= c \[) (recur (rest cs) (inc d) out)
          (= c \]) (recur (rest cs) (dec d) out)
          (= c \,) (recur (rest cs) d out)
          :else    (recur (rest cs) d (conj out [(- (int c) (int \0)) d])))))))

(defn explode [f]
  (when-let [i (first (keep-indexed (fn [i [_ d]] (when (> d 4) i)) f))]
    (let [[l _] (nth f i) [r _] (nth f (inc i)) d (second (nth f i))]
      (-> (vec (concat (subvec f 0 i) [[0 (dec d)]] (subvec f (+ i 2))))
          (cond-> (pos? i) (update-in [(dec i) 0] + l))
          (cond-> (< (+ i 2) (count f)) (update-in [(inc i) 0] + r))))))

(defn split-one [f]
  (when-let [i (first (keep-indexed (fn [i [v _]] (when (>= v 10) i)) f))]
    (let [[v d] (nth f i)]
      (vec (concat (subvec f 0 i) [[(quot v 2) (inc d)] [(quot (inc v) 2) (inc d)]] (subvec f (inc i)))))))

(defn reduce-num [f]
  (loop [f f]
    (if-let [f' (explode f)] (recur f')
      (if-let [f' (split-one f)] (recur f') f))))

(defn add [a b] (reduce-num (vec (concat (map (fn [[v d]] [v (inc d)]) a)
                                         (map (fn [[v d]] [v (inc d)]) b)))))

(defn magnitude [f]
  (loop [f f]
    (if (= 1 (count f))
      (first (first f))
      (let [m (apply max (map second f))
            i (first (for [i (range (dec (count f)))
                           :when (and (= m (second (nth f i))) (= m (second (nth f (inc i)))))]
                       i))]
        (recur (vec (concat (subvec f 0 i)
                            [[(+ (* 3 (first (nth f i))) (* 2 (first (nth f (inc i))))) (dec m)]]
                            (subvec f (+ i 2)))))))))

(def nums (mapv flatten-num lines))

(println "=>" (magnitude (reduce add nums)))
(println "=>" (apply max (for [i (range (count nums)) j (range (count nums)) :when (not= i j)]
                           (magnitude (add (nums i) (nums j))))))
