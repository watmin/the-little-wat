;; oracle/sicp/ch21-data-abstraction.scm: our own Scheme on the topic of SICP §2.1, data
;; abstraction: rational arithmetic built on constructors and selectors, the abstraction barrier
;; that lets the representation change underneath, and the section's closing question -- what IS
;; a pair? -- answered by building one out of nothing but procedures. Our code and our examples.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- rational numbers: constructor, selectors, and arithmetic that never looks inside ---
(define (my-gcd a b) (if (= b 0) a (my-gcd b (remainder a b))))

(define (make-rat n d)
  (let* ((g (my-gcd (abs n) (abs d)))
         (sign (if (< (* n d) 0) -1 1)))
    (cons (* sign (quotient (abs n) g)) (quotient (abs d) g))))
(define (numer x) (car x))
(define (denom x) (cdr x))

(define (rat->string x) (string-append (number->string (numer x)) "/" (number->string (denom x))))

(define (add-rat x y)
  (make-rat (+ (* (numer x) (denom y)) (* (numer y) (denom x))) (* (denom x) (denom y))))
(define (sub-rat x y)
  (make-rat (- (* (numer x) (denom y)) (* (numer y) (denom x))) (* (denom x) (denom y))))
(define (mul-rat x y) (make-rat (* (numer x) (numer y)) (* (denom x) (denom y))))
(define (div-rat x y) (make-rat (* (numer x) (denom y)) (* (denom x) (numer y))))
(define (equal-rat? x y) (= (* (numer x) (denom y)) (* (numer y) (denom x))))

(define one-half (make-rat 1 2))
(define one-third (make-rat 1 3))

(show (rat->string one-half))
(show (rat->string (add-rat one-half one-third)))
(show (rat->string (sub-rat one-half one-third)))
(show (rat->string (mul-rat one-half one-third)))
(show (rat->string (div-rat one-half one-third)))
(show (equal-rat? (make-rat 1 2) (make-rat 2 4)))
(show (equal-rat? (make-rat 1 2) (make-rat 1 3)))

;; --- reduction to lowest terms happens in the CONSTRUCTOR, so every client benefits ---
(show (rat->string (make-rat 6 9)))
(show (rat->string (make-rat -6 9)))
(show (rat->string (make-rat 6 -9)))
(show (rat->string (make-rat -6 -9)))
(show (rat->string (add-rat one-third (add-rat one-third one-third))))

;; --- what IS a pair? (Exercise 2.4) a pair made of nothing but procedures ---
;; cons returns a procedure; car and cdr apply it to a chooser. No data structure is involved.
(define (pcons x y) (lambda (m) (m x y)))
(define (pcar z) (z (lambda (p q) p)))
(define (pcdr z) (z (lambda (p q) q)))

(show (pcar (pcons 3 4)))
(show (pcdr (pcons 3 4)))
;; and the rationals work unchanged on it, because they only ever used the interface
(define (make-rat2 n d)
  (let* ((g (my-gcd (abs n) (abs d)))
         (sign (if (< (* n d) 0) -1 1)))
    (pcons (* sign (quotient (abs n) g)) (quotient (abs d) g))))
(define (numer2 x) (pcar x))
(define (denom2 x) (pcdr x))
(define (rat2->string x) (string-append (number->string (numer2 x)) "/" (number->string (denom2 x))))
(show (rat2->string (make-rat2 6 9)))
(show (rat2->string (make-rat2 -6 -9)))

;; --- an interval, the section's other example: arithmetic whose selectors are the whole story ---
(define (make-interval a b) (cons a b))
(define (lower-bound i) (car i))
(define (upper-bound i) (cdr i))
(define (add-interval x y)
  (make-interval (+ (lower-bound x) (lower-bound y)) (+ (upper-bound x) (upper-bound y))))
(define (int->string i)
  (string-append "[" (number->string (lower-bound i)) "," (number->string (upper-bound i)) "]"))
(show (int->string (add-interval (make-interval 1 2) (make-interval 3 5))))
(show (int->string (make-interval 1 2)))
