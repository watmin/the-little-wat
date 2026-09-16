;; oracle/sicp/ch34-concurrency.scm: our own Scheme on the topic of SICP §3.4, concurrency: what
;; access to one account must add up to, however the accesses are interleaved. Our code and our
;; examples, not the book's text.
;;
;; Scheme here runs one thing at a time, so it computes what any correct serialization must
;; produce: the sums are the same whatever the order. The wat chapter does the same work from
;; several threads at once, through one account service, and must arrive at these numbers.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define (make-account balance)
  (define (withdraw amount)
    (if (>= balance amount)
        (begin (set! balance (- balance amount)) balance)
        'insufficient))
  (define (deposit amount)
    (set! balance (+ balance amount))
    balance)
  (define (dispatch m)
    (cond ((eq? m 'withdraw) withdraw)
          ((eq? m 'deposit) deposit)
          ((eq? m 'balance) (lambda () balance))
          (else (error "make-account: unknown request" m))))
  dispatch)

;; one worker's share of the work: n deposits of 1
(define (deposit-times! acc n)
  (if (= n 0)
      'done
      (begin ((acc 'deposit) 1) (deposit-times! acc (- n 1)))))

;; a transfer moves what it takes: the two balances together never change
(define (transfer! from to amount)
  (let ((left ((from 'withdraw) amount)))
    (if (eq? left 'insufficient)
        'insufficient
        (begin ((to 'deposit) amount) left))))

;; ---- four workers, each depositing 1 twenty-five times

(define acc (make-account 0))
(show ((acc 'balance)))
(deposit-times! acc 25)
(deposit-times! acc 25)
(deposit-times! acc 25)
(deposit-times! acc 25)
(show ((acc 'balance)))

;; ---- transfers between two accounts keep the total

(define a (make-account 100))
(define b (make-account 100))
(show (transfer! a b 30))
(show ((a 'balance)))
(show ((b 'balance)))
(show (transfer! b a 50))
(show ((a 'balance)))
(show ((b 'balance)))
(show (+ ((a 'balance)) ((b 'balance))))
(show (transfer! a b 1000))
(show (+ ((a 'balance)) ((b 'balance))))
