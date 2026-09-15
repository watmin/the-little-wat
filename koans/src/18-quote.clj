;; Quote: our own filled-in koans on the topic of the Clojure Koans' eighteenth file.

;; quote returns its form unevaluated
(= (quote (4 5 6)) '(4 5 6))

;; ' is quote
(= '(4 5 6) (quote (4 5 6)))

;; a quoted symbol is the symbol, not its value
(= 'age (let [age 9] (quote age)))

;; cons onto a quoted list, a built list, a vector
(= (cons 1 '(2 3)) (list 1 2 3) (cons 1 [2 3]))

;; quote stops evaluation inside
(= (list 1 '(+ 2 3)) '(1 (+ 2 3)))

;; syntax-quote of plain values
(= (list 1 2 3) `(1 2 3) '(1 2 3))

;; unquote evaluates inside a syntax-quote
(= (list 1 5) `(1 ~(+ 2 3)) '(1 5))
