;; oracle/aoc/day07-packets.clj: the reference implementation for aoc/day07-packets.wat.
;;
;; The puzzle is ours, in Advent of Code's bit-transmission shape. A hexadecimal string expands to
;; a bit string; a packet is 3 bits of version, 3 bits of type, and then either a literal (4-bit
;; groups, each with a continue bit) or an operator carrying sub-packets, counted either by how
;; many there are or by how many bits they occupy.
;;
;; Part one: the sum of every version number in the transmission.
;; Part two: the value of the expression the packets describe.
;;
;; Clojure has bit-and, bit-shift-right and Long/parseLong with a radix, and uses them. wat has
;; none of the first two (F-035), which is the point of the wat port.
;;
;; Run by tools/aoc-oracle.sh with the clojure CLI; every "=> " line is an expected answer.

(def hex (clojure.string/trim (slurp "aoc/input/day07-packets.txt")))

(def bits
  (apply str (map (fn [c] (let [v (Long/parseLong (str c) 16)]
                            (clojure.string/replace (format "%4s" (Long/toBinaryString v)) " " "0")))
                  hex)))

(defn bval [s a b] (Long/parseLong (subs s a b) 2))

(declare parse)

;; parse one packet starting at i; returns [version-sum value next-index]
(defn parse-literal [i]
  (loop [j (+ i 6) acc 0]
    (let [more (= \1 (nth bits j))
          nib  (bval bits (inc j) (+ j 5))
          acc' (+ (* acc 16) nib)]
      (if more (recur (+ j 5) acc') [acc' (+ j 5)]))))

(defn apply-op [t vs]
  (case t
    0 (reduce + vs)
    1 (reduce * vs)
    2 (reduce min vs)
    3 (reduce max vs)
    5 (if (> (first vs) (second vs)) 1 0)
    6 (if (< (first vs) (second vs)) 1 0)
    7 (if (= (first vs) (second vs)) 1 0)))

(defn parse [i]
  (let [ver (bval bits i (+ i 3))
        typ (bval bits (+ i 3) (+ i 6))]
    (if (= typ 4)
      (let [[v nxt] (parse-literal i)] [ver v nxt])
      (let [lt (nth bits (+ i 6))]
        (if (= \0 lt)
          (let [len (bval bits (+ i 7) (+ i 22)) stop (+ i 22 len)]
            (loop [j (+ i 22) vs [] vsum ver]
              (if (>= j stop) [vsum (apply-op typ vs) j]
                  (let [[sv v nxt] (parse j)] (recur nxt (conj vs v) (+ vsum sv))))))
          (let [n (bval bits (+ i 7) (+ i 18))]
            (loop [j (+ i 18) k 0 vs [] vsum ver]
              (if (>= k n) [vsum (apply-op typ vs) j]
                  (let [[sv v nxt] (parse j)] (recur nxt (inc k) (conj vs v) (+ vsum sv)))))))))))

(defn show [v] (println (str "=> " v)))

(def result (parse 0))

(show (count hex))
(show (count bits))
(show (subs bits 0 12))
(show (first result))    ; part one: the sum of the versions
(show (second result))   ; part two: the value
;; a couple of field extractions on their own, so the wat port can check its bit arithmetic
(show (bval bits 0 3))
(show (bval bits 3 6))
(show (bval bits 7 22))

;; --- and one thing that arithmetic CANNOT stand in for ---
;; Shifting is multiplying by a power of two and masking is quot/rem, so a bit-field decoder needs
;; no bit operations at all. XOR is different: it is not expressible as +, -, * or quot on the
;; whole numbers, so wat must build it a bit at a time. Clojure just calls bit-xor.
(def literals
  (letfn [(lits [i]
            (let [typ (bval bits (+ i 3) (+ i 6))]
              (if (= typ 4)
                (let [[v nxt] (parse-literal i)] [[v] nxt])
                (let [lt (nth bits (+ i 6))]
                  (if (= \0 lt)
                    (let [len (bval bits (+ i 7) (+ i 22)) stop (+ i 22 len)]
                      (loop [j (+ i 22) acc []]
                        (if (>= j stop) [acc j]
                            (let [[vs nxt] (lits j)] (recur nxt (into acc vs))))))
                    (let [n (bval bits (+ i 7) (+ i 18))]
                      (loop [j (+ i 18) k 0 acc []]
                        (if (>= k n) [acc j]
                            (let [[vs nxt] (lits j)] (recur nxt (inc k) (into acc vs)))))))))))]
    (first (lits 0))))

(show literals)
(show (reduce bit-xor literals))
(show (reduce bit-and (map #(+ % 8) literals)))
(show (bit-xor 6 7))
(show (bit-and 12 10))
