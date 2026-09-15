;; Recursion: our own filled-in koans on the topic of the Clojure Koans' fourteenth file.

(defn even-steps? [n] (if (= n 0) true (not (even-steps? (dec n)))))

(defn even-loop? [n] (loop [n n acc true] (if (= n 0) acc (recur (dec n) (not acc)))))

(defn my-reverse [coll] (if (empty? coll) '() (concat (my-reverse (rest coll)) (list (first coll)))))

(defn fact [n] (if (< n 2) 1 (* n (fact (dec n)))))

;; zero is even
(= true (even-steps? 0))

;; one is not
(= false (even-steps? 1))

;; a loop counts far without growing the stack
(= false (even-loop? 100001))

;; the reverse of one element
(= '(1) (my-reverse [1]))

;; the reverse of several
(= '(9 8 7 6) (my-reverse [6 7 8 9]))

;; factorial of 1
(= 1 (fact 1))

;; of 3
(= 6 (fact 3))

;; of 4
(= 24 (fact 4))

;; of 5
(= 120 (fact 5))

;; of 20, the largest that fits a long
(= 2432902008176640000 (fact 20))

;; of 25, which needs a bignum
(< 1000000000000000000000000N (fact 25N))
