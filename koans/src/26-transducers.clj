;; Transducers: our own filled-in koans on the topic of the Clojure Koans' twenty-sixth file.

(def add-one (map inc))

(def evens-after-inc (comp (map inc) (filter even?)))

;; a transducer, applied by sequence
(= '(2 3 4) (sequence add-one [1 2 3]))

;; transduce, with conj
(= [2 4] (transduce evens-after-inc conj [1 2 3]))

;; into, through a transducer
(= [2 4] (into [] evens-after-inc [1 2 3]))

;; sequence, through a composed one
(= '(2 4) (sequence evens-after-inc [1 2 3]))

;; transduce, with +
(= 6 (transduce evens-after-inc + [1 2 3]))
