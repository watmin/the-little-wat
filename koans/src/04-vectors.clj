;; Vectors: our own filled-in koans on the topic of the Clojure Koans' fourth file.

;; how many in a vector
(= 1 (count [7]))

;; a vector from a list
(= [7] (vec '(7)))

;; a vector of its arguments
(= [nil] (vector nil))

;; vec of a longer list
(= [7 8] (vec '(7 8)))

;; conj on a vector adds at the end
(= [4 5 6] (conj [4 5] 6))

;; the first
(= :pear (first [:pear :plum :fig :date]))

;; the last
(= :date (last [:pear :plum :fig :date]))

;; by index
(= :date (nth [:pear :plum :fig :date] 3))

;; a subvector
(= [:plum :fig] (subvec [:pear :plum :fig :date] 1 3))

;; a list and a vector with the same elements are equal
(= true (= '(4 5 6) [4 5 6]))
