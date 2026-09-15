;; Sequence comprehensions: our own filled-in koans on the topic of the Clojure Koans' twelfth file.

;; for over a range
(= '(0 1 2 3) (for [x (range 4)] x))

;; for, computing each element
(= '(0 2 4 6) (for [x (range 4)] (* 2 x)))

;; for, with a filter
(= '(0 2 4 6 8) (for [x (range 10) :when (even? x)] x))

;; filter, and compute
(= '(0 4 16 36 64) (for [x (range 10) :when (even? x)] (* x x)))

;; two bindings nest
(= [[:a 1] [:a 2] [:b 1] [:b 2]] (for [l [:a :b] n [1 2]] [l n]))
