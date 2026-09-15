;; Lists: our own filled-in koans on the topic of the Clojure Koans' third file.

;; a list, built or quoted
(= '(4 5 6) (list 4 5 6))

;; the first of a list
(= 4 (first '(4 5 6)))

;; the rest of a list
(= '(5 6) (rest '(4 5 6)))

;; how many
(= 3 (count '(pear plum fig)))

;; an empty list has none
(= 0 (count '()))

;; the rest of a one-element list is empty
(= '() (rest '(fig)))

;; cons puts an element on the front
(= '(:x :y :z) (cons :x '(:y :z)))

;; conj on a list also adds at the front
(= '(:w :x :y :z) (conj '(:x :y :z) :w))

;; a list as a stack: peek at the top
(= :x (peek '(:x :y :z)))

;; and pop it
(= '(:y :z) (pop '(:x :y :z)))

;; popping an empty list is an error
(= "empty" (try (pop '()) (catch IllegalStateException e "empty")))

;; but the rest of an empty list is just empty
(= '() (rest '()))
