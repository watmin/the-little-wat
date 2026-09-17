;; oracle/paip/ch13-object-oriented.scm: our own Scheme on the topic of PAIP chapter 13, object
;; oriented programming -- objects as CLOSURES that answer messages, and then generic functions
;; that dispatch on the types of ALL their arguments rather than just the first. Our code and our
;; examples; Norvig's own code is not read or copied.
;;
;; The chapter's arc is from the first to the second, and the second is the interesting one: CLOS
;; picks a method by looking at every argument, so `(collide asteroid ship)` and
;; `(collide asteroid asteroid)` can run different code even though the first argument is the same.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- objects as closures: the object IS a procedure that takes a message ---
(define (make-account balance)
  (lambda (msg . args)
    (cond ((eq? msg 'balance) balance)
          ((eq? msg 'deposit) (make-account (+ balance (car args))))
          ((eq? msg 'withdraw) (if (> (car args) balance) 'insufficient
                                   (make-account (- balance (car args)))))
          (else 'unknown-message))))

(define a1 (make-account 100))
(show (a1 'balance))
(show ((a1 'deposit 50) 'balance))
(show ((a1 'withdraw 30) 'balance))
(show (a1 'withdraw 500))
(show (a1 'fly))
;; the original is untouched: each message answers a NEW account
(show (a1 'balance))

;; --- single dispatch: one type tag picks the method ---
(define (tag-of x) (car x))
(define (single-dispatch table op x)
  (let ((h (assoc (list op (tag-of x)) table)))
    (if h ((cdr h) x) 'no-method)))

(define area-table
  (list (cons '(area square) (lambda (s) (* (cadr s) (cadr s))))
        (cons '(area rect) (lambda (s) (* (cadr s) (caddr s))))))

(show (single-dispatch area-table 'area '(square 4)))
(show (single-dispatch area-table 'area '(rect 3 5)))
(show (single-dispatch area-table 'area '(circle 2)))

;; --- MULTIPLE dispatch: the method is chosen by BOTH argument types ---
(define collide-table
  (list (cons '(collide asteroid ship) (lambda (a b) 'ship-destroyed))
        (cons '(collide asteroid asteroid) (lambda (a b) 'both-shatter))
        (cons '(collide ship ship) (lambda (a b) 'both-damaged))))

(define (multi-dispatch table op x y)
  (let ((h (assoc (list op (tag-of x) (tag-of y)) table)))
    (if h ((cdr h) x y) 'no-method)))

(show (multi-dispatch collide-table 'collide '(asteroid) '(ship)))
(show (multi-dispatch collide-table 'collide '(asteroid) '(asteroid)))
(show (multi-dispatch collide-table 'collide '(ship) '(ship)))
;; the FIRST argument is the same in these two and the answers differ: that is the whole point
(show (eq? (multi-dispatch collide-table 'collide '(asteroid) '(ship))
           (multi-dispatch collide-table 'collide '(asteroid) '(asteroid))))
;; a combination no method covers
(show (multi-dispatch collide-table 'collide '(ship) '(asteroid)))
;; how many methods a single-dispatch language would need for n types: one per PAIR
(show (length collide-table))
