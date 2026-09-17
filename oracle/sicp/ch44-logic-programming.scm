;; oracle/sicp/ch44-logic-programming.scm: our own Scheme on the topic of SICP §4.4, logic
;; programming -- a database of facts, PATTERN MATCHING with variables, unification, and rules
;; that derive new answers from old ones. Our code and our examples, not the book's text.
;;
;; The section's point is that a query language computes in a different direction from a
;; procedure: `(job ?x (computer programmer))` asks who, and `(job (Bitdiddle Ben) ?y)` asks what,
;; from the SAME fact. Both are checked below.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a variable is the symbol ? followed by nothing else: we spell them ?x, ?y, ?who
(define (var? x) (and (symbol? x) (char=? #\? (string-ref (symbol->string x) 0))))

;; --- unification over nested lists, with a frame of bindings ---
(define (binding-of v frame) (assq v frame))
(define (extend v val frame) (cons (cons v val) frame))

(define (lookup-val exp frame)
  (if (and (var? exp) (binding-of exp frame))
      (lookup-val (cdr (binding-of exp frame)) frame)
      exp))

(define (unify p d frame)
  (cond ((eq? frame 'fail) 'fail)
        ((equal? p d) frame)
        ((var? p) (unify-var p d frame))
        ((var? d) (unify-var d p frame))
        ((and (pair? p) (pair? d))
         (unify (cdr p) (cdr d) (unify (car p) (car d) frame)))
        (else 'fail)))

(define (unify-var v val frame)
  (let ((b (binding-of v frame)))
    (cond (b (unify (cdr b) val frame))
          ((var? val) (let ((b2 (binding-of val frame)))
                        (if b2 (unify v (cdr b2) frame) (extend v val frame))))
          (else (extend v val frame)))))

;; --- the database ---
(define facts
  '((job (Bitdiddle Ben) (computer wizard))
    (job (Hacker Alyssa P) (computer programmer))
    (job (Fect Cy D) (computer programmer))
    (job (Tweakit Lem E) (computer technician))
    (job (Reasoner Louis) (computer programmer trainee))
    (salary (Bitdiddle Ben) 60000)
    (salary (Hacker Alyssa P) 40000)
    (salary (Fect Cy D) 35000)
    (supervisor (Hacker Alyssa P) (Bitdiddle Ben))
    (supervisor (Fect Cy D) (Bitdiddle Ben))
    (supervisor (Tweakit Lem E) (Bitdiddle Ben))))

;; every frame in which the pattern matches some fact
(define (match-pattern pattern frame)
  (let loop ((fs facts) (out '()))
    (if (null? fs) (reverse out)
        (let ((r (unify pattern (car fs) frame)))
          (loop (cdr fs) (if (eq? r 'fail) out (cons r out)))))))

;; what a variable is bound to, in each answer
(define (values-of v frames) (map (lambda (f) (lookup-val v f)) frames))

(show (length facts))
(show (length (match-pattern '(job ?person ?title) '())))
;; ask WHO: same fact shape, variable in the first position
(show (values-of '?person (match-pattern '(job ?person (computer programmer)) '())))
;; ask WHAT: variable in the second position instead
(show (values-of '?title (match-pattern '(job (Bitdiddle Ben) ?title) '())))
;; a partially instantiated pattern: everyone in the computer division
(show (length (match-pattern '(job ?person (computer . ?rest)) '())))
(show (values-of '?who (match-pattern '(supervisor ?who (Bitdiddle Ben)) '())))
(show (values-of '?amount (match-pattern '(salary (Hacker Alyssa P) ?amount) '())))
;; no match at all
(show (match-pattern '(job (Nobody Here) ?title) '()))

;; --- unification proper: two patterns, not just pattern against ground fact ---
;; the bindings are read back by name rather than printed raw, so that Scheme's dotted-pair
;; rendering of a frame is not what the two implementations are being compared on
(show (lookup-val '?x (unify '(?x ?y) '(1 2) '())))
(show (lookup-val '?y (unify '(?x ?y) '(1 2) '())))
(show (eq? 'fail (unify '(?x ?x) '(1 1) '())))
(show (eq? 'fail (unify '(?x ?x) '(1 2) '())))
(show (lookup-val '?x (unify '(f ?x) '(f (g ?y)) '())))
(show (eq? 'fail (unify '(f ?x) '(g ?x) '())))

;; --- a RULE, applied by hand: same-division holds when two people share a first job word ---
(define (division-of person)
  (let ((r (match-pattern (list 'job person '?title) '())))
    (if (null? r) 'none (car (lookup-val '?title (car r))))))
(show (division-of '(Bitdiddle Ben)))
(show (division-of '(Reasoner Louis)))
(show (eq? (division-of '(Bitdiddle Ben)) (division-of '(Fect Cy D))))
