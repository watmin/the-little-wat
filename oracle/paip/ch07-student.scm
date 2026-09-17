;; oracle/paip/ch07-student.scm: our own Scheme on the topic of PAIP chapter 7, STUDENT --
;; translating algebra word problems into equations and then SOLVING them by isolating one
;; variable at a time. Our code and our examples; Norvig's own code is not read or copied.
;;
;; Two halves, and the second is the one with teeth. Translation is pattern matching over word
;; lists, which chapter 5 already did. Solving is an algorithm with a real failure mode: an
;; equation can only be isolated if the unknown occurs EXACTLY ONCE, and a system can only be
;; solved if each step leaves a one-unknown equation. Both failures are tested.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; an expression: a number, a symbol, or (op lhs rhs)
(define (op? e) (and (pair? e) (= 3 (length e))))
(define (op-of e) (car e)) (define (lhs e) (cadr e)) (define (rhs e) (caddr e))

;; how many times does the unknown occur?
(define (occurrences x e)
  (cond ((eq? x e) 1)
        ((op? e) (+ (occurrences x (lhs e)) (occurrences x (rhs e))))
        (else 0)))

(define (in? x e) (> (occurrences x e) 0))

;; isolate: rewrite (lhs = rhs) so that `x` stands alone on the left
(define (isolate eq x)
  (let ((l (lhs eq)) (r (rhs eq)))
    (cond ((eq? l x) eq)
          ((not (op? l)) 'fail)
          ((in? x (lhs l))
           ;; x is inside the left operand: move the right operand across
           (isolate (list '= (lhs l) (invert-right (op-of l) r (rhs l))) x))
          ((in? x (rhs l))
           (isolate (list '= (rhs l) (invert-left (op-of l) r (lhs l))) x))
          (else 'fail))))

;; (a OP b) = r, solving for a
(define (invert-right op r b)
  (cond ((eq? op '+) (list '- r b))
        ((eq? op '-) (list '+ r b))
        ((eq? op '*) (list '/ r b))
        ((eq? op '/) (list '* r b))
        (else 'fail)))
;; (a OP b) = r, solving for b
(define (invert-left op r a)
  (cond ((eq? op '+) (list '- r a))
        ((eq? op '*) (list '/ r a))
        ((eq? op '-) (list '- a r))
        ((eq? op '/) (list '/ a r))
        (else 'fail)))

;; evaluate an expression once every symbol in it is bound
(define (evaluate e bindings)
  (cond ((number? e) e)
        ((symbol? e) (let ((h (assq e bindings))) (if h (cdr h) 'unbound)))
        ((op? e)
         (let ((a (evaluate (lhs e) bindings)) (b (evaluate (rhs e) bindings)))
           (if (or (eq? a 'unbound) (eq? b 'unbound)) 'unbound
               (case (op-of e) ((+) (+ a b)) ((-) (- a b)) ((*) (* a b)) ((/) (quotient a b)) (else 'unbound)))))
        (else 'unbound)))

;; solve one equation for one unknown, given what is already known
(define (solve-one eq x known)
  (let ((iso (isolate eq x)))
    (if (eq? iso 'fail) 'fail (evaluate (rhs iso) known))))

(show (occurrences 'x '(= x 5)))
(show (occurrences 'x '(= (+ x x) 10)))
(show (occurrences 'x '(= (+ y 3) 10)))
;; isolate, then read off the answer
(show (solve-one '(= (+ x 3) 10) 'x '()))
(show (solve-one '(= (* 2 x) 12) 'x '()))
(show (solve-one '(= (- x 4) 6) 'x '()))
(show (solve-one '(= (/ x 3) 5) 'x '()))
;; the unknown on the RIGHT of the operator
(show (solve-one '(= (- 20 x) 8) 'x '()))
(show (solve-one '(= (/ 24 x) 4) 'x '()))
;; nested
(show (solve-one '(= (+ (* 2 x) 1) 11) 'x '()))
;; using something already known
(show (solve-one '(= (+ x y) 10) 'x '((y . 4))))
;; the failure that matters: the unknown occurs TWICE, so isolating is not possible
(show (eq? 'fail (isolate '(= (+ x x) 10) 'x)))
;; and an equation that does not mention the unknown at all
(show (eq? 'fail (isolate '(= (+ y 3) 10) 'x)))

;; --- translation: words to an equation, by pattern ---
(define (translate words)
  (cond ((match-prefix '(what is) words) (list 'unknown (cddr words)))
        (else 'no-rule)))
(define (match-prefix p w) (cond ((null? p) #t) ((null? w) #f)
                                 ((eq? (car p) (car w)) (match-prefix (cdr p) (cdr w))) (else #f)))
(show (car (translate '(what is 3 plus 4))))
(show (translate '(nothing matches this)))

;; --- solving a SYSTEM, one equation at a time ---
;; each round, find an equation with exactly one unknown left, solve it, and record the value
(define (unknowns-in e known)
  (cond ((symbol? e) (if (assq e known) '() (list e)))
        ((op? e) (append (unknowns-in (lhs e) known) (unknowns-in (rhs e) known)))
        (else '())))

(define (solve-system eqs known)
  (if (null? eqs) known
      (let loop ((es eqs) (skipped '()))
        (if (null? es) 'fail
            (let* ((eq (car es)) (us (unknowns-in eq known)))
              (if (and (= 1 (length us)) (= 1 (occurrences (car us) eq)))
                  (let ((v (solve-one eq (car us) known)))
                    (if (eq? v 'unbound) 'fail
                        (solve-system (append (reverse skipped) (cdr es)) (cons (cons (car us) v) known))))
                  (loop (cdr es) (cons eq skipped))))))))

(define sys '((= (+ x y) 10) (= y 4)))
(show (cdr (assq 'x (solve-system sys '()))))
(show (cdr (assq 'y (solve-system sys '()))))
;; a system with no way in: every equation has two unknowns
(show (eq? 'fail (solve-system '((= (+ x y) 10) (= (+ x z) 8)) '())))
