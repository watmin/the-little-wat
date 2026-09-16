;; oracle/sicp/ch35-streams.scm: our own Scheme on the topic of SICP §3.5, streams: a sequence
;; whose rest is delayed, so an endless one can be described and only as much of it computed as
;; is asked for. Our code and our examples, not the book's text.
;;
;; guile has delay and force; cons-stream is the book's special form, defined here. What a
;; forced stream remembers is measured in probes/sicp/stream-memo.wat instead, where wat's
;; answer can differ without failing a chapter.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define-syntax cons-stream
  (syntax-rules ()
    ((_ a b) (cons a (delay b)))))

(define the-empty-stream '())
(define (stream-null? s) (null? s))
(define (stream-car s) (car s))
(define (stream-cdr s) (force (cdr s)))

(define (stream-head s n)
  (if (= n 0)
      '()
      (cons (stream-car s) (stream-head (stream-cdr s) (- n 1)))))

(define (stream-ref s n)
  (if (= n 0) (stream-car s) (stream-ref (stream-cdr s) (- n 1))))

(define (stream-map f s)
  (if (stream-null? s)
      the-empty-stream
      (cons-stream (f (stream-car s)) (stream-map f (stream-cdr s)))))

(define (stream-filter keep? s)
  (cond ((stream-null? s) the-empty-stream)
        ((keep? (stream-car s)) (cons-stream (stream-car s) (stream-filter keep? (stream-cdr s))))
        (else (stream-filter keep? (stream-cdr s)))))

(define (stream-map2 f a b)
  (cons-stream (f (stream-car a) (stream-car b))
               (stream-map2 f (stream-cdr a) (stream-cdr b))))

;; ---- endless streams

(define (integers-from n) (cons-stream n (integers-from (+ n 1))))
(define integers (integers-from 1))

(define (divisible? a b) (= 0 (remainder a b)))

(define (sieve s)
  (cons-stream (stream-car s)
               (sieve (stream-filter (lambda (n) (not (divisible? n (stream-car s))))
                                     (stream-cdr s)))))
(define primes (sieve (integers-from 2)))

;; the same two seeds the wat port uses, so both describe the sequence the same way
(define (fibs-from a b) (cons-stream a (fibs-from b (+ a b))))
(define fibs (fibs-from 0 1))

;; ---- results

(show (stream-head integers 5))
(show (stream-ref integers 99))
(show (stream-head (stream-map (lambda (n) (* n n)) integers) 5))
(show (stream-head (stream-filter even? integers) 5))
(show (stream-head primes 8))
(show (stream-ref primes 20))
(show (stream-head fibs 10))
(show (stream-ref fibs 30))
(show (stream-head (stream-map2 + integers integers) 5))
