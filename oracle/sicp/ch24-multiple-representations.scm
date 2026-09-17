;; oracle/sicp/ch24-multiple-representations.scm: our own Scheme on the topic of SICP §2.4,
;; multiple representations for abstract data -- complex numbers held rectangularly and polarly,
;; reached three ways: explicit dispatch on a type tag, DATA-DIRECTED dispatch through a table of
;; (operation, type) pairs, and MESSAGE PASSING, where the object is itself a procedure.
;; Our code and our examples, not the book's text.
;;
;; Floats are reported as tolerance comparisons, so formatting cannot fail a passing chapter.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))
(define (near? a b eps) (< (abs (- a b)) eps))
(define (square x) (* x x))

;; --- 1. explicit dispatch on a type tag ---
(define (attach-tag type contents) (cons type contents))
(define (type-tag datum) (car datum))
(define (contents datum) (cdr datum))

(define (make-from-real-imag-rect x y) (attach-tag 'rectangular (cons x y)))
(define (make-from-mag-ang-polar r a) (attach-tag 'polar (cons r a)))

(define (real-part-rect z) (car z))
(define (imag-part-rect z) (cdr z))
(define (magnitude-rect z) (sqrt (+ (square (car z)) (square (cdr z)))))
(define (angle-rect z) (atan (cdr z) (car z)))

(define (real-part-polar z) (* (car z) (cos (cdr z))))
(define (imag-part-polar z) (* (car z) (sin (cdr z))))
(define (magnitude-polar z) (car z))
(define (angle-polar z) (cdr z))

(define (real-part z)
  (cond ((eq? (type-tag z) 'rectangular) (real-part-rect (contents z)))
        ((eq? (type-tag z) 'polar) (real-part-polar (contents z)))
        (else (error "unknown type"))))
(define (imag-part z)
  (cond ((eq? (type-tag z) 'rectangular) (imag-part-rect (contents z)))
        ((eq? (type-tag z) 'polar) (imag-part-polar (contents z)))
        (else (error "unknown type"))))
(define (magnitude z)
  (cond ((eq? (type-tag z) 'rectangular) (magnitude-rect (contents z)))
        ((eq? (type-tag z) 'polar) (magnitude-polar (contents z)))
        (else (error "unknown type"))))
(define (angle z)
  (cond ((eq? (type-tag z) 'rectangular) (angle-rect (contents z)))
        ((eq? (type-tag z) 'polar) (angle-polar (contents z)))
        (else (error "unknown type"))))

(define z-rect (make-from-real-imag-rect 3.0 4.0))
(define z-polar (make-from-mag-ang-polar 5.0 0.0))

(show (near? (real-part z-rect) 3.0 0.0001))
(show (near? (imag-part z-rect) 4.0 0.0001))
(show (near? (magnitude z-rect) 5.0 0.0001))
(show (near? (real-part z-polar) 5.0 0.0001))
(show (near? (imag-part z-polar) 0.0 0.0001))
(show (near? (magnitude z-polar) 5.0 0.0001))

;; addition is written ONCE, against the selectors, and works across representations
(define (add-complex z1 z2)
  (make-from-real-imag-rect (+ (real-part z1) (real-part z2)) (+ (imag-part z1) (imag-part z2))))
(show (near? (real-part (add-complex z-rect z-polar)) 8.0 0.0001))
(show (near? (imag-part (add-complex z-rect z-polar)) 4.0 0.0001))
(show (near? (magnitude (add-complex z-rect z-rect)) 10.0 0.0001))

;; --- 2. DATA-DIRECTED: a table keyed by (operation, type) ---
(define the-table '())
(define (put op type item) (set! the-table (cons (list op type item) the-table)))
(define (get op type)
  (let loop ((t the-table))
    (cond ((null? t) #f)
          ((and (eq? (car (car t)) op) (eq? (cadr (car t)) type)) (caddr (car t)))
          (else (loop (cdr t))))))

(put 'real-part 'rectangular real-part-rect)
(put 'imag-part 'rectangular imag-part-rect)
(put 'magnitude 'rectangular magnitude-rect)
(put 'real-part 'polar real-part-polar)
(put 'imag-part 'polar imag-part-polar)
(put 'magnitude 'polar magnitude-polar)

(define (apply-generic op z)
  (let ((proc (get op (type-tag z))))
    (if proc (proc (contents z)) (error "no method"))))

(show (near? (apply-generic 'real-part z-rect) 3.0 0.0001))
(show (near? (apply-generic 'magnitude z-rect) 5.0 0.0001))
(show (near? (apply-generic 'real-part z-polar) 5.0 0.0001))
(show (near? (apply-generic 'magnitude z-polar) 5.0 0.0001))
;; a table entry that is not there is a MISS, discoverable without running the operation
(show (if (get 'angle 'polar) #t #f))
(show (if (get 'nonesuch 'polar) #t #f))

;; --- 3. MESSAGE PASSING: the object IS a procedure ---
(define (make-from-real-imag-msg x y)
  (lambda (op)
    (cond ((eq? op 'real-part) x)
          ((eq? op 'imag-part) y)
          ((eq? op 'magnitude) (sqrt (+ (square x) (square y))))
          (else (error "unknown op")))))

(define zm (make-from-real-imag-msg 3.0 4.0))
(show (near? (zm 'real-part) 3.0 0.0001))
(show (near? (zm 'imag-part) 4.0 0.0001))
(show (near? (zm 'magnitude) 5.0 0.0001))

;; all three agree on the same number
(show (near? (real-part z-rect) (apply-generic 'real-part z-rect) 0.0001))
(show (near? (magnitude z-rect) (zm 'magnitude) 0.0001))
