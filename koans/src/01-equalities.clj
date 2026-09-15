;; Equalities: our own filled-in koans on the topic of the Clojure Koans' first file.

;; truth is true
(= true true)

;; one and one
(= 2 (+ 1 1))

;; = takes any number of arguments
(= (+ 2 5) 7 (+ 3 4))

;; a ratio that is a whole number is that integer
(= true (= 3 6/2))

;; an integer is not equal to a float
(= false (= 3 3.0))

;; == compares numbers by value
(= true (== 3.0 3))

;; a number is not nil
(= true (not (= 0 nil)))

;; a string, a keyword and a symbol are all different
(= false (= "pear" :pear 'pear))

;; a keyword made from a string
(= :pear (keyword "pear"))

;; a symbol made from a string
(= 'pear (symbol "pear"))

;; nil equals only nil
(= nil nil)

;; two different things are not=
(not= :pear :plum)
