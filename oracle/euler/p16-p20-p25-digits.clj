;; oracle/euler/p16-p20-p25-digits.clj: the expected answers for euler/p16-p20-p25-digits.wat.
;;
;; Our own Clojure on three Project Euler problems that turn on arbitrary-precision integers.
;; Project Euler's problem statements are not reproduced; the wat solution states each in its
;; own words. The answers are the point.
;;
;;   p16  the sum of the digits of 2^1000
;;   p20  the sum of the digits of 100!
;;   p25  the index of the first Fibonacci term with 1000 digits
;;
;; Each is chosen to press on F-047: a wat bigint computes but cannot be compared, and has no
;; to-string. p16 and p20 need a bigint's DIGITS; p25 needs to know when one has reached 1000 of
;; them, which is the comparison question asked a different way.
;;
;; Every line printed after "=> " is an answer the wat solution must print, in order.
;;
;; Run: tools/euler-oracle.sh p16-p20-p25-digits

(defn digit-sum [n]
  (reduce + (map #(Character/digit % 10) (str n))))

(defn pow2 [n]
  (.pow (biginteger 2) n))

(defn factorial [n]
  (reduce * (bigint 1) (range 1 (inc n))))

;; the first Fibonacci term with d digits, counting F1 = F2 = 1
(defn fib-index-with-digits [d]
  (loop [a (bigint 1) b (bigint 1) i 2]
    (if (>= (count (str b)) d)
      i
      (recur b (+ a b) (inc i)))))

(defn say [x] (println "=>" x))

;; p16: the digits of 2^1000
(say (digit-sum (pow2 1000)))
;; and a smaller one, so a wrong answer says where it went wrong
(say (digit-sum (pow2 15)))

;; p20: the digits of 100!
(say (digit-sum (factorial 100)))
(say (digit-sum (factorial 10)))

;; p25: the first Fibonacci term with 1000 digits, and with 3
(say (fib-index-with-digits 1000))
(say (fib-index-with-digits 3))

;; the digit counts themselves, since that is what a wat bigint can answer without a comparison
(say (count (str (pow2 1000))))
(say (count (str (factorial 100))))
