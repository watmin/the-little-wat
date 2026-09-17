;; oracle/paip/ch08-symbolic-math.scm: our own Scheme on the topic of PAIP chapter 8, symbolic
;; mathematics -- a simplifier driven by a TABLE OF REWRITE RULES rather than by hand-written
;; cases, applied repeatedly until nothing changes. Our code and our examples; Norvig's own code
;; is not read or copied.
;;
;; The contrast worth drawing is with SICP §2.3, where differentiation is a procedure with one
;; clause per operator. Here the rules are DATA: `(+ ?x 0) => ?x` is a pair of patterns, and
;; adding an identity means adding a row, not editing a function. The cost is that the rules must
;; be applied to a FIXED POINT, and that a bad rule set can fail to terminate.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define (var? x) (and (symbol? x) (char=? #\? (string-ref (symbol->string x) 0))))

;; --- matching an expression against a rule's left-hand side ---
(define (pat-match p e b)
  (cond ((eq? b 'fail) 'fail)
        ((var? p) (let ((old (assq p b))) (if old (if (equal? (cdr old) e) b 'fail) (cons (cons p e) b))))
        ((and (pair? p) (pair? e))
         (pat-match (cdr p) (cdr e) (pat-match (car p) (car e) b)))
        ((equal? p e) b)
        (else 'fail)))

(define (subst-bindings b x)
  (cond ((var? x) (let ((h (assq x b))) (if h (cdr h) x)))
        ((pair? x) (cons (subst-bindings b (car x)) (subst-bindings b (cdr x))))
        (else x)))

;; --- the rules, as data ---
(define rules
  '(((+ ?x 0) ?x) ((+ 0 ?x) ?x)
    ((* ?x 1) ?x) ((* 1 ?x) ?x)
    ((* ?x 0) 0)  ((* 0 ?x) 0)
    ((- ?x 0) ?x) ((- ?x ?x) 0)
    ((/ ?x 1) ?x) ((/ ?x ?x) 1)
    ((^ ?x 1) ?x) ((^ ?x 0) 1)
    ((d ?x ?x) 1)
    ((d (+ ?u ?v) ?x) (+ (d ?u ?x) (d ?v ?x)))
    ((d (- ?u ?v) ?x) (- (d ?u ?x) (d ?v ?x)))
    ((d (* ?u ?v) ?x) (+ (* ?u (d ?v ?x)) (* ?v (d ?u ?x))))))

;; a constant's derivative is 0; handled outside the table because it needs a test, not a pattern
(define (const-deriv e)
  (and (pair? e) (eq? (car e) 'd) (number? (cadr e)) 0))
(define (other-var-deriv e)
  (and (pair? e) (eq? (car e) 'd) (symbol? (cadr e)) (not (eq? (cadr e) (caddr e))) 0))

(define (apply-rules e)
  (or (const-deriv e) (other-var-deriv e)
      (let loop ((rs rules))
        (if (null? rs) e
            (let ((b (pat-match (car (car rs)) e '())))
              (if (eq? b 'fail) (loop (cdr rs)) (subst-bindings b (cadr (car rs)))))))))

;; arithmetic on literal numbers, so (+ 2 3) folds
(define (fold e)
  (if (and (pair? e) (= 3 (length e)) (number? (cadr e)) (number? (caddr e))
           (memq (car e) '(+ - *)))
      (cond ((eq? (car e) '+) (+ (cadr e) (caddr e)))
            ((eq? (car e) '-) (- (cadr e) (caddr e)))
            (else (* (cadr e) (caddr e))))
      e))

;; simplify bottom-up, then apply rules at the top, repeatedly until nothing changes
(define (simplify e)
  (let ((s (simplify-once e)))
    (if (equal? s e) e (simplify s))))

(define (simplify-once e)
  (if (not (pair? e)) e
      (fold (apply-rules (cons (car e) (map simplify-once (cdr e)))))))

(show (simplify '(+ x 0)))
(show (simplify '(* x 1)))
(show (simplify '(* x 0)))
(show (simplify '(- x x)))
(show (simplify '(/ x x)))
(show (simplify '(^ x 1)))
(show (simplify '(+ (* x 0) (* 1 y))))
(show (simplify '(+ 2 3)))
(show (simplify '(* (+ 2 3) (^ x 0))))
(show (simplify '(+ (* 1 x) (* 0 y))))

;; --- differentiation, by the same rules ---
(show (simplify '(d x x)))
(show (simplify '(d 5 x)))
(show (simplify '(d y x)))
(show (simplify '(d (+ x 5) x)))
(show (simplify '(d (* x y) x)))
(show (simplify '(d (* x x) x)))
(show (simplify '(d (+ (* x y) 3) x)))
;; the same expression SICP §2.3 differentiates by hand
(show (simplify '(d (* (* x y) (+ x 3)) x)))
