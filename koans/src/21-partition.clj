;; Partition: our own filled-in koans on the topic of the Clojure Koans' twenty-first file.

;; partition into pairs
(= '((0 1) (2 3)) (partition 2 (range 4)))

;; an incomplete last group is dropped
(= '((:a :b :c)) (partition 3 [:a :b :c :d :e]))

;; partition-all keeps it
(= '((0 1 2) (3 4)) (partition-all 3 (range 5)))

;; a step larger than the size skips
(= '((0 1 2) (5 6 7) (10 11 12)) (partition 3 5 (range 13)))

;; a pad fills the last group
(= '((0 1 2) (3 4 5) (6 :pad)) (partition 3 3 [:pad] (range 7)))

;; a pad longer than needed is cut
(= '((0 1 2) (3 4 5) (6 :p :q)) (partition 3 3 [:p :q :r :s] (range 7)))
