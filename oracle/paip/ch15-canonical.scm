;; oracle/paip/ch15-canonical.scm: our own Scheme on the topic of PAIP chapter 15, symbolic
;; mathematics with CANONICAL FORMS -- a polynomial held as a dense vector of coefficients, so that
;; two equal polynomials are the SAME object and equality is structural rather than a search.
;; Our code and our examples; Norvig's own code is not read or copied.
;;
;; The contrast with chapter 8 is the whole point. There, `x + x` and `2x` are different trees that
;; a rule set may or may not reconcile, and the simplifier runs to a fixed point hoping. Here they
;; are the same coefficient vector the moment they are built, and `equal?` decides it.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a polynomial in one variable: coefficients from degree 0 up, with no trailing zeros
(define (trim p) (let loop ((r (reverse p))) (cond ((null? r) '(0)) ((= 0 (car r)) (loop (cdr r))) (else (reverse r)))))
(define (poly . cs) (trim cs))
(define (degree p) (- (length p) 1))
(define (coeff p n) (if (< n (length p)) (list-ref p n) 0))

(define (p+ a b)
  (let ((n (max (length a) (length b))))
    (trim (let loop ((i 0) (out '()))
            (if (= i n) (reverse out) (loop (+ i 1) (cons (+ (coeff a i) (coeff b i)) out)))))))

(define (p* a b)
  (let ((n (+ (length a) (length b))))
    (trim (let loop ((k 0) (out '()))
            (if (= k n) (reverse out)
                (loop (+ k 1)
                      (cons (let inner ((i 0) (s 0))
                              (if (> i k) s (inner (+ i 1) (+ s (* (coeff a i) (coeff b (- k i)))))))
                            out)))))))

(define (pscale p k) (trim (map (lambda (c) (* c k)) p)))
(define (pderiv p) (trim (let loop ((i 1) (out '()))
                           (if (>= i (length p)) (reverse out)
                               (loop (+ i 1) (cons (* i (coeff p i)) out))))))
(define (peval p x) (let loop ((i 0) (s 0)) (if (>= i (length p)) s (loop (+ i 1) (+ s (* (coeff p i) (expt x i)))))))

(define x (poly 0 1))          ; the polynomial x
(define one (poly 1))

(show x)
(show (degree x))
(show (p+ x x))
;; x + x and 2x are THE SAME OBJECT, with no simplification step at all
(show (equal? (p+ x x) (pscale x 2)))
(show (p* x x))
(show (degree (p* x x)))
(show (p+ (p* x x) (p+ (pscale x 2) one)))       ; x^2 + 2x + 1
(show (p* (p+ x one) (p+ x one)))                 ; (x+1)^2
;; the canonical form makes the identity CHECKABLE rather than provable
(show (equal? (p+ (p* x x) (p+ (pscale x 2) one)) (p* (p+ x one) (p+ x one))))
;; and a false identity is just as cheap to refute
(show (equal? (p* (p+ x one) (p+ x one)) (p+ (p* x x) one)))
(show (pderiv (p* x x)))
(show (pderiv (p+ (p* x x) (p+ (pscale x 2) one))))
(show (peval (p+ (p* x x) (p+ (pscale x 2) one)) 3))
(show (peval (p* (p+ x one) (p+ x one)) 3))
;; subtracting a polynomial from itself gives the canonical zero, not a tree that means zero
(show (p+ (p* x x) (pscale (p* x x) -1)))
(show (degree (p+ (p* x x) (pscale (p* x x) -1))))
