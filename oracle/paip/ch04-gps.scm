;; oracle/paip/ch04-gps.scm: our own Scheme on the topic of PAIP chapter 4, the General Problem
;; Solver -- MEANS-ENDS ANALYSIS. A state is a set of conditions; an operator has preconditions, an
;; add-list and a delete-list; achieving a goal means finding an operator that adds it and then
;; achieving that operator's preconditions first. Our code and our examples; Norvig's own code is
;; not read or copied.
;;
;; The chapter is really about the program's BUGS, so the failures are tested as carefully as the
;; successes: a goal with no operator, a missing precondition deep in the chain, and the
;; "prerequisite clobbers sibling goal" case where achieving one goal undoes another.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; an operator: (name preconds add-list del-list)
(define (op-name o) (car o))
(define (op-preconds o) (cadr o))
(define (op-add o) (caddr o))
(define (op-del o) (cadddr o))

(define school-ops
  '((drive-son-to-school (son-at-home car-works) (son-at-school) (son-at-home))
    (shop-installs-battery (car-needs-battery shop-knows-problem shop-has-money) (car-works) ())
    (tell-shop-problem (in-communication-with-shop) (shop-knows-problem) ())
    (telephone-shop (know-phone-number) (in-communication-with-shop) ())
    (look-up-number (have-phone-book) (know-phone-number) ())
    (give-shop-money (have-money) (shop-has-money) (have-money))))

(define (mem? x s) (if (memq x s) #t #f))
(define (remove-all xs s) (if (null? xs) s (remove-all (cdr xs) (delq-all (car xs) s))))
(define (delq-all x s) (cond ((null? s) '()) ((eq? x (car s)) (delq-all x (cdr s))) (else (cons (car s) (delq-all x (cdr s))))))
(define (add-all xs s) (if (null? xs) s (add-all (cdr xs) (if (mem? (car xs) s) s (cons (car xs) s)))))

;; achieve: 'fail, or a new state. `stack` is the goals currently being pursued, to stop looping.
(define (achieve goal state ops stack)
  (cond ((mem? goal state) state)
        ((mem? goal stack) 'fail)                      ; already pursuing it: a loop
        (else (try-ops (applicable ops goal) goal state ops (cons goal stack)))))

(define (applicable ops goal) (filter (lambda (o) (mem? goal (op-add o))) ops))

(define (try-ops cands goal state ops stack)
  (if (null? cands) 'fail
      (let ((r (apply-op (car cands) state ops stack)))
        (if (eq? r 'fail) (try-ops (cdr cands) goal state ops stack) r))))

(define (apply-op o state ops stack)
  (let ((s (achieve-all (op-preconds o) state ops stack)))
    (if (eq? s 'fail) 'fail (add-all (op-add o) (remove-all (op-del o) s)))))

(define (achieve-all goals state ops stack)
  (if (null? goals) state
      (let ((s (achieve (car goals) state ops stack)))
        (if (eq? s 'fail) 'fail (achieve-all (cdr goals) s ops stack)))))

(define (gps state goals ops)
  (let ((s (achieve-all goals state ops '())))
    (if (eq? s 'fail) 'fail (if (all-in? goals s) 'solved 'fail))))

(define (all-in? goals s) (if (null? goals) #t (and (mem? (car goals) s) (all-in? (cdr goals) s))))

;; --- the school problem, solvable ---
(define start '(son-at-home car-needs-battery have-money have-phone-book))
(show (gps start '(son-at-school) school-ops))
;; already satisfied: nothing to do
(show (gps start '(son-at-home) school-ops))
;; a goal no operator adds
(show (gps start '(son-at-university) school-ops))
;; without the phone book the chain breaks at look-up-number
(show (gps '(son-at-home car-needs-battery have-money) '(son-at-school) school-ops))
;; without money it breaks at give-shop-money
(show (gps '(son-at-home car-needs-battery have-phone-book) '(son-at-school) school-ops))
;; the car already works: a much shorter chain, same answer
(show (gps '(son-at-home car-works) '(son-at-school) school-ops))

;; --- the PREREQUISITE CLOBBERS SIBLING GOAL problem ---
;; getting the son to school spends the money, so the two goals cannot both hold at the end,
;; and the order they are asked in decides whether the bug shows.
(show (gps start '(son-at-school have-money) school-ops))
(show (gps start '(have-money son-at-school) school-ops))
(show (eq? (gps start '(son-at-school have-money) school-ops)
           (gps start '(have-money son-at-school) school-ops)))

;; --- what the final state actually contains, for the solvable case ---
(define final (achieve-all '(son-at-school) start school-ops '()))
(show (mem? 'son-at-school final))
(show (mem? 'son-at-home final))
(show (mem? 'car-works final))
(show (mem? 'have-money final))
