;; oracle/sicp/ch11-elements.scm: our own Scheme on the topic of SICP §1.1, the elements of
;; programming: compound procedures, the substitution model, conditionals, and a square root by
;; Newton's method built out of nothing but those. Our code and our examples, not the book's text.
;;
;; The section's real subject is that a procedure definition is an abstraction you can then forget
;; the inside of, and that `if` must NOT evaluate both arms -- the recursion below does not
;; terminate otherwise. Both are checked here.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- compound procedures, and composing them ---
(define (square x) (* x x))
(define (sum-of-squares x y) (+ (square x) (square y)))
(define (f a) (sum-of-squares (+ a 1) (* a 2)))

(show (square 21))
(show (sum-of-squares 3 4))
(show (f 5))

;; --- conditionals, and the fact that `if` is not a procedure ---
(define (abs-val x) (if (< x 0) (- x) x))
(show (abs-val -7))
(show (abs-val 7))

;; a procedure whose second arm would diverge if `if` evaluated both:
;;   were `if` an ordinary call, (loop-forever) would be evaluated before the choice was made.
(define (loop-forever n) (loop-forever n))
(define (safe-if-demo x) (if (> x 0) x (loop-forever x)))
(show (safe-if-demo 42))

;; --- Newton's method for square roots, the section's worked example ---
(define (average a b) (/ (+ a b) 2))
(define (good-enough? guess x) (< (abs (- (square guess) x)) 0.001))
(define (improve guess x) (average guess (/ x guess)))
(define (sqrt-iter guess x)
  (if (good-enough? guess x) guess (sqrt-iter (improve guess x) x)))
(define (my-sqrt x) (sqrt-iter 1.0 x))

(show (< (abs (- (my-sqrt 9.0) 3.0)) 0.001))
(show (< (abs (- (my-sqrt 2.0) 1.4142135)) 0.001))
(show (< (abs (- (square (my-sqrt 25.0)) 25.0)) 0.001))

;; --- block structure: the helpers belong INSIDE, and x need not be passed down ---
(define (sqrt2 x)
  (define (good? guess) (< (abs (- (square guess) x)) 0.001))
  (define (improve2 guess) (average guess (/ x guess)))
  (define (iter guess) (if (good? guess) guess (iter (improve2 guess))))
  (iter 1.0))

(show (< (abs (- (sqrt2 9.0) 3.0)) 0.001))
(show (< (abs (- (sqrt2 2.0) (my-sqrt 2.0))) 0.0000001))

;; --- the substitution model, made observable: applicative order evaluates arguments first ---
;; (f 5) above is (sum-of-squares 6 10) is (+ (square 6) (square 10)) is (+ 36 100).
(show (+ (square 6) (square 10)))
(show (= (f 5) (+ 36 100)))
