;; oracle/sicp/ch13-higher-order.scm: our own Scheme on the topic of SICP §1.3, abstractions built
;; with higher-order procedures: procedures as arguments, lambda and let, general methods
;; (half-interval search, fixed points), and procedures RETURNED from procedures. Our code and our
;; examples, not the book's text.
;;
;; Floats are reported as tolerance comparisons rather than printed, so that guile's and wat's
;; float formatting cannot make a passing chapter look like a failing one -- the same choice
;; ch11-elements.scm makes.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))
(define (near? a b eps) (< (abs (- a b)) eps))
(define (square x) (* x x))
(define (cube x) (* x x x))

;; --- procedures as ARGUMENTS: one `sum` for every summation ---
(define (sum term a next b)
  (if (> a b) 0 (+ (term a) (sum term (next a) next b))))
(define (inc n) (+ n 1))
(define (identity x) x)

(define (sum-integers a b) (sum identity a inc b))
(define (sum-cubes a b) (sum cube a inc b))

(show (sum-integers 1 10))
(show (sum-cubes 1 10))
(show (= (sum-cubes 1 10) (square (sum-integers 1 10))))

;; the same `sum` again, with a lambda instead of a named term
(show (sum (lambda (x) (* x x)) 1 (lambda (x) (+ x 1)) 10))

;; and a PRODUCT, to show the pattern was the abstraction, not the addition
(define (product term a next b)
  (if (> a b) 1 (* (term a) (product term (next a) next b))))
(show (product identity 1 inc 5))

;; --- an integral: the same `sum`, with dx fixed by a let ---
(define (integral f a b dx)
  (define (add-dx x) (+ x dx))
  (* (sum f (+ a (/ dx 2.0)) add-dx b) dx))
(show (near? (integral cube 0.0 1.0 0.001) 0.25 0.001))

;; --- procedures as GENERAL METHODS: half-interval search for a root ---
(define (positive? x) (> x 0))
(define (negative? x) (< x 0))
(define (search f neg-point pos-point)
  (let ((midpoint (/ (+ neg-point pos-point) 2.0)))
    (if (< (abs (- pos-point neg-point)) 0.0001)
        midpoint
        (let ((test-value (f midpoint)))
          (cond ((positive? test-value) (search f neg-point midpoint))
                ((negative? test-value) (search f midpoint pos-point))
                (else midpoint))))))
(define (half-interval f a b)
  (let ((a-value (f a)) (b-value (f b)))
    (cond ((and (negative? a-value) (positive? b-value)) (search f a b))
          ((and (negative? b-value) (positive? a-value)) (search f b a))
          (else 0.0))))

(show (near? (half-interval (lambda (x) (- (square x) 2.0)) 1.0 2.0) 1.4142135 0.001))
(show (near? (half-interval sin 2.0 4.0) 3.14159 0.001))

;; --- fixed points ---
(define (fixed-point f first-guess)
  (define (try guess)
    (let ((next (f guess)))
      (if (near? guess next 0.00001) next (try next))))
  (try first-guess))

(show (near? (fixed-point cos 1.0) 0.7390851 0.0001))
;; sqrt as a fixed point of y -> x/y DIVERGES by oscillation; average damping fixes it
(define (average a b) (/ (+ a b) 2.0))
(define (average-damp f) (lambda (x) (average x (f x))))

(show (near? (fixed-point (average-damp (lambda (y) (/ 2.0 y))) 1.0) 1.4142135 0.0001))
(show (near? ((average-damp square) 10.0) 55.0 0.0001))

;; --- procedures RETURNED from procedures: the derivative, and Newton's method ---
(define dx 0.00001)
(define (deriv g) (lambda (x) (/ (- (g (+ x dx)) (g x)) dx)))
(show (near? ((deriv cube) 5.0) 75.0 0.01))

(define (newton-transform g) (lambda (x) (- x (/ (g x) ((deriv g) x)))))
(define (newtons-method g guess) (fixed-point (newton-transform g) guess))
(define (sqrt-newton x) (newtons-method (lambda (y) (- (square y) x)) 1.0))

(show (near? (sqrt-newton 9.0) 3.0 0.0001))
(show (near? (sqrt-newton 2.0) 1.4142135 0.0001))

;; --- the same sqrt, two ways, as one abstraction ---
(define (fixed-point-of-transform g transform guess) (fixed-point (transform g) guess))
(define (sqrt-damp x) (fixed-point-of-transform (lambda (y) (/ x y)) average-damp 1.0))
(define (sqrt-newt x) (fixed-point-of-transform (lambda (y) (- (square y) x)) newton-transform 1.0))

(show (near? (sqrt-damp 25.0) 5.0 0.0001))
(show (near? (sqrt-newt 25.0) 5.0 0.0001))
(show (near? (sqrt-damp 25.0) (sqrt-newt 25.0) 0.001))

;; --- compose, the smallest higher-order procedure there is ---
(define (compose f g) (lambda (x) (f (g x))))
(show ((compose square inc) 6))
(define (repeated f n) (if (= n 1) f (compose f (repeated f (- n 1)))))
(show ((repeated square 2) 5))
(show ((repeated inc 10) 0))
