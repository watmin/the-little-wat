;; Atoms: our own filled-in koans on the topic of the Clojure Koans' seventeenth file.

(def counter (atom 0))

;; deref an atom
(= 0 @counter)

;; swap! applies a function
(= 1 (do (reset! counter 0) (swap! counter inc) @counter))

;; reset! sets it
(= 5 (do (reset! counter 5) @counter))

;; swap! passes more arguments along
(= 15 (do (reset! counter 0) (swap! counter + 1 2 3 4 5) @counter))

;; compare-and-set! when the old value doesn't match
(= 15 (do (reset! counter 15) (compare-and-set! counter 100 :done) @counter))

;; and when it does
(= :done (do (reset! counter 15) (compare-and-set! counter 15 :done) @counter))
