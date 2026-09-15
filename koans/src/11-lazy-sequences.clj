;; Lazy sequences: our own filled-in koans on the topic of the Clojure Koans' eleventh file.

;; a range from a start to before an end
(= '(2 3 4) (range 2 5))

;; a range from zero
(= '(0 1 2) (range 3))

;; take from a long range
(= [0 1 2 3] (take 4 (range 50)))

;; drop from it
(= [47 48 49] (drop 47 (range 50)))

;; iterate a function
(= [1 3 9 27 81] (take 5 (iterate (fn [x] (* x 3)) 1)))

;; repeat a value
(= [:z :z :z] (repeat 3 :z))

;; an endless iteration, taken
(= (repeat 5 "hi") (take 5 (iterate identity "hi")))
