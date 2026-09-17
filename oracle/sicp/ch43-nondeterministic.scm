;; oracle/sicp/ch43-nondeterministic.scm: our own Scheme on the topic of SICP §4.3, nondeterministic
;; computing -- `amb`, which chooses, and a search that BACKTRACKS when a later requirement fails.
;; Our code and our examples, not the book's text.
;;
;; The section's machinery is two continuations: an evaluator carries a SUCCESS continuation (here
;; is a value, and here is how to ask for another) and a FAILURE continuation (there are no more).
;; `amb` tries its choices in order, handing each to success with a failure that moves to the next.
;; `require` fails when its condition is false, which is what makes the whole thing a search.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- an amb-evaluator in the small: expressions are (amb e ...), (require p), or values ---
;; A computation is a procedure of (succeed fail), where succeed takes (value retry).
(define (unit x) (lambda (succeed fail) (succeed x fail)))

(define (amb-of choices)
  (lambda (succeed fail)
    (let try ((cs choices))
      (if (null? cs) (fail)
          (succeed (car cs) (lambda () (try (cdr cs))))))))

(define (bind m f)
  (lambda (succeed fail)
    (m (lambda (value retry) ((f value) succeed retry)) fail)))

(define (require-that ok? m)
  (bind m (lambda (v) (lambda (succeed fail) (if (ok? v) (succeed v fail) (fail))))))

;; run: the first answer, or 'none
(define (first-of m) (m (lambda (v retry) v) (lambda () 'none)))
;; run: every answer, by asking `retry` until it fails
(define (all-of m)
  (m (lambda (v retry) (cons v (retry))) (lambda () '())))

(show (first-of (unit 5)))
(show (all-of (amb-of '(1 2 3))))
(show (first-of (amb-of '(1 2 3))))
(show (all-of (amb-of '())))
(show (first-of (amb-of '())))

;; require prunes: only the even choices survive
(show (all-of (require-that even? (amb-of '(1 2 3 4 5 6)))))
(show (first-of (require-that even? (amb-of '(1 3 5)))))

;; --- two ambs and a requirement between them: this is the backtracking search ---
(define (pairs-summing-to n lo hi)
  (all-of (bind (amb-of (iota-from lo hi))
                (lambda (a)
                  (bind (require-that (lambda (b) (= n (+ a b))) (amb-of (iota-from lo hi)))
                        (lambda (b) (unit (list a b))))))))
(define (iota-from lo hi) (if (> lo hi) '() (cons lo (iota-from (+ lo 1) hi))))

(show (pairs-summing-to 5 1 4))
(show (pairs-summing-to 8 1 4))
(show (length (pairs-summing-to 5 1 4)))

;; --- Pythagorean triples, the section's own example shape ---
(define (triples n)
  (all-of (bind (amb-of (iota-from 1 n))
                (lambda (a)
                  (bind (amb-of (iota-from a n))
                        (lambda (b)
                          (bind (require-that (lambda (c) (= (* c c) (+ (* a a) (* b b))))
                                              (amb-of (iota-from b n)))
                                (lambda (c) (unit (list a b c))))))))))
(show (triples 20))
(show (length (triples 20)))

;; the order of the answers is the order `amb` tries its choices -- depth first, left to right
(show (all-of (bind (amb-of '(1 2)) (lambda (a) (bind (amb-of '(10 20)) (lambda (b) (unit (list a b))))))))
