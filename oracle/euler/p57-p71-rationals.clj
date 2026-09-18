;; oracle/euler/p57-p71-rationals.clj: the reference implementation for
;; euler/p57-p71-rationals.wat. Our own Clojure; Project Euler's problem statements are not
;; reproduced, and each file states its problems in its own words.
;;
;; p57 -- the continued-fraction convergents of the square root of two: 3/2, 7/5, 17/12, …, each
;;        built from the last by n/d -> (n+2d)/(n+d). In how many of the first thousand does the
;;        numerator have more digits than the denominator?
;; p71 -- list every reduced fraction below 3/7 with denominator at most a million, in order of
;;        size. What is the numerator of the one immediately to the left of 3/7?
;;
;; Clojure is the oracle because its ratios and bigints are the closest thing to what wat claims
;; to have. This file uses `<` on ratios and on bigints freely; the wat port cannot (F-047), which
;; is the point.
;;
;; Run by tools/euler-oracle.sh with the clojure CLI; every "=> " line is an expected answer.

(defn show [v] (println (str "=> " v)))

;; --- p57: bigint numerators, and the digit counts that decide each term ---
(def convergents
  (take 1000 (iterate (fn [[n d]] [(+ n (* 2 d)) (+ n d)]) [3N 2N])))

(def wider (count (filter (fn [[n d]] (> (count (str n)) (count (str d)))) convergents)))

(show (count convergents))
(show (str (first (nth convergents 0))) )
(show (str (second (nth convergents 0))))
(show (str (first (nth convergents 7))))
(show (str (second (nth convergents 7))))
(show wider)
;; the numerators really do outgrow i64 -- the last one is hundreds of digits long
(show (count (str (first (last convergents)))))
(show (> (count (str (first (last convergents)))) 300))

;; --- p71: ORDERING fractions, which is the verb wat does not have ---
;; Clojure compares ratios directly; the wat port must cross-multiply.
(def target (/ 3 7))
(def answer
  (loop [d 2 bn 0 bd 1]
    (if (> d 1000000)
      [bn bd]
      (let [n (quot (- (* 3 d) 1) 7)]
        (if (> (/ n d) (/ bn bd)) (recur (inc d) n d) (recur (inc d) bn bd))))))

(show (first answer))
(show (second answer))
;; and the ordering facts the wat port has to reproduce without `<` on a ratio
(show (< (/ 1 4) (/ 3 4)))
(show (< (/ 428570 999997) target))
(show (= (/ 1 2) (/ 2 4)))
