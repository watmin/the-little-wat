;; Creating functions: our own filled-in koans on the topic of the Clojure Koans' thirteenth file.

(defn square [x] (* x x))

;; the complement of a predicate
(= [true false true] (let [not-a-keyword? (complement keyword?)] (map not-a-keyword? ["a" :b 'c])))

;; a predicate made by hand
(= [:x "x" 'x] (let [not-nil? (fn [v] (not (nil? v)))] (filter not-nil? [nil :x nil "x" 'x])))

;; partial application
(= 21 (let [times-7 (partial * 7)] (times-7 3)))

;; partial application, with a collection
(= [:a :b :c :d] (let [ab (partial concat [:a :b])] (ab [:c :d])))

;; composition
(= 16 (let [inc-then-square (comp square inc)] (inc-then-square 3)))

;; a function composed with itself
(= 7 (let [dec-twice (comp dec dec)] (dec-twice 9)))

;; composition, the other way round
(= 99 (let [square-then-dec (comp dec square)] (square-then-dec 10)))
