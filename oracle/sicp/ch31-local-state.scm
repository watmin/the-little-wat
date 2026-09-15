;; oracle/sicp/ch31-local-state.scm: our own Scheme on the topic of SICP §3.1, procedures with
;; local state: an account that remembers its balance, an accumulator, a procedure that counts
;; its own calls, and two names for one account. Our code and our examples, not the book's text.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; an account is a procedure that dispatches on a message; its balance is local to it
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

(define (make-accumulator total)
  (lambda (amount)
    (set! total (+ total amount))
    total))

(define (make-monitored f)
  (define calls 0)
  (lambda (arg)
    (if (eq? arg 'how-many-calls?)
        calls
        (begin (set! calls (+ calls 1)) (f arg)))))

(define (square n) (* n n))

;; ---- an account remembers

(define acc (make-account 100))
(show ((acc 'withdraw) 30))
(show ((acc 'withdraw) 80))
(show ((acc 'deposit) 50))
(show ((acc 'withdraw) 60))
(show ((acc 'balance)))

;; ---- a second account has its own balance

(define acc2 (make-account 100))
(show ((acc2 'withdraw) 10))
(show ((acc2 'balance)))
(show ((acc 'balance)))

;; ---- two names for one account are one balance

(define peter acc)
(define paul acc)
(show ((peter 'withdraw) 10))
(show ((paul 'balance)))
(show ((paul 'deposit) 25))
(show ((peter 'balance)))

;; ---- an accumulator

(define a (make-accumulator 5))
(show (a 10))
(show (a 10))
(define b (make-accumulator 5))
(show (b 1))
(show (a 1))

;; ---- a procedure that counts its own calls

(define ms (make-monitored square))
(show (ms 5))
(show (ms 'how-many-calls?))
(show (ms 3))
(show (ms 'how-many-calls?))
