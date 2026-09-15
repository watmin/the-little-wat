;; Higher-order functions: our own filled-in koans on the topic of the Clojure Koans' ninth file.

;; map a function over a vector
(= [3 6 9] (map (fn [x] (* 3 x)) [1 2 3]))

;; map to squares
(= [1 4 9 16] (map (fn [x] (* x x)) [1 2 3 4]))

;; map a predicate
(= [false true false] (map nil? [:a nil :b]))

;; filter that keeps nothing
(= '() (filter (fn [x] false) '(:a :b :c)))

;; filter that keeps everything
(= '(:a :b :c) (filter (fn [x] true) '(:a :b :c)))

;; filter by a test
(= [5 10 15] (filter (fn [x] (< x 20)) [5 10 15 20 25]))

;; map after filter
(= [10 20 30] (map (fn [x] (* 10 x)) (filter (fn [x] (< x 4)) [1 2 3 4 5])))

;; reduce: the product
(= 120 (reduce (fn [a b] (* a b)) [1 2 3 4 5]))

;; reduce with a starting value
(= 240 (reduce (fn [a b] (* a b)) 2 [1 2 3 4 5]))

;; reduce to the longest word
(= "longest" (reduce (fn [a b] (if (< (count a) (count b)) b a)) ["which" "is" "longest"]))
