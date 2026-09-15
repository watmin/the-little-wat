;; Sets: our own filled-in koans on the topic of the Clojure Koans' fifth file.

;; a set from a collection
(= #{7} (set [7 7 7]))

;; how many in a set
(= 3 (count #{:a :b :c}))

;; duplicates vanish
(= #{1 2 3} (set '(1 2 2 3 3 3)))

;; union
(= #{1 2 3 4 5} (set/union #{1 2 3} #{3 4 5}))

;; intersection
(= #{3} (set/intersection #{1 2 3} #{3 4 5}))

;; difference
(= #{1 2} (set/difference #{1 2 3} #{3 4 5}))
