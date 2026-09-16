;; oracle/paip/ch12-prolog.scm: the expected answers for paip/ch12-prolog.wat.
;;
;; Our own Scheme on chapter 12's topic — a Prolog built on chapter 11's unifier — written from
;; the algorithm, not from Norvig's code, which is neither read nor copied here.
;;
;; A clause is (head . body): a list whose first element is the conclusion and whose rest are
;; the goals that must hold for it. A fact is a clause with an empty body. The database is a
;; list of clauses, built once and only read.
;;
;; Proving a goal means: for each clause whose head unifies with the goal, prove the clause's
;; body under the resulting bindings. A clause's variables are RENAMED apart before each
;; attempt (?x becomes ?x.1, ?x.2, …), or the same rule used twice in one proof would collide
;; with itself.
;;
;; Answers are the bindings of the QUERY's own variables — the renamed ones are plumbing and
;; are resolved away — printed canonically: sorted by variable name, each as (?var value), the
;; same shape ch11 prints. A query with no solutions prints "fail"; a query that succeeds with
;; nothing bound prints "yes".
;;
;; Every line printed after "=> " is a result the wat port must print, in order.
;;
;; Run: tools/paip-oracle.sh ch12-prolog

(use-modules (ice-9 format) (srfi srfi-1))

;; ---- chapter 11, as much of it as chapter 12 needs

(define fail 'fail)
(define no-bindings '())

(define (variable? x)
  (and (symbol? x)
       (let ((s (symbol->string x)))
         (and (> (string-length s) 0)
              (char=? (string-ref s 0) #\?)))))

(define (get-binding var bindings) (assq var bindings))
(define (binding-val b) (cdr b))
(define (lookup var bindings)
  (let ((b (get-binding var bindings)))
    (if b (binding-val b) #f)))
(define (extend-bindings var val bindings) (cons (cons var val) bindings))

(define (occurs-in? var x bindings)
  (cond ((eq? var x) #t)
        ((and (variable? x) (get-binding x bindings))
         (occurs-in? var (lookup x bindings) bindings))
        ((pair? x) (or (occurs-in? var (car x) bindings)
                       (occurs-in? var (cdr x) bindings)))
        (else #f)))

(define (unify-variable var x bindings)
  (cond ((get-binding var bindings) (unify (lookup var bindings) x bindings))
        ((and (variable? x) (get-binding x bindings))
         (unify var (lookup x bindings) bindings))
        ((occurs-in? var x bindings) fail)
        (else (extend-bindings var x bindings))))

(define (unify x y bindings)
  (cond ((eq? bindings fail) fail)
        ((equal? x y) bindings)
        ((variable? x) (unify-variable x y bindings))
        ((variable? y) (unify-variable y x bindings))
        ((and (pair? x) (pair? y))
         (unify (cdr x) (cdr y) (unify (car x) (car y) bindings)))
        (else fail)))

(define (subst-bindings bindings x)
  (cond ((eq? bindings fail) fail)
        ((null? bindings) x)
        ((and (variable? x) (get-binding x bindings))
         (subst-bindings bindings (lookup x bindings)))
        ((pair? x) (cons (subst-bindings bindings (car x))
                         (subst-bindings bindings (cdr x))))
        (else x)))

;; ---- chapter 12: clauses, renaming, and proof

(define (clause-head c) (car c))
(define (clause-body c) (cdr c))

;; every variable in x, in order of first appearance
(define (variables-in x)
  (let loop ((x x) (found '()))
    (cond ((variable? x) (if (memq x found) found (cons x found)))
          ((pair? x) (loop (cdr x) (loop (car x) found)))
          (else found))))

;; ?x becomes ?x.N, so a clause used twice never collides with itself
(define counter 0)
(define (next-n!) (set! counter (+ counter 1)) counter)

(define (rename-clause c)
  (let* ((n (next-n!))
         (vars (variables-in c))
         (bs (map (lambda (v)
                    (cons v (string->symbol
                              (string-append (symbol->string v) "." (number->string n)))))
                  vars)))
    (let rename ((x c))
      (cond ((variable? x) (let ((b (assq x bs))) (if b (cdr b) x)))
            ((pair? x) (cons (rename (car x)) (rename (cdr x))))
            (else x)))))

;; every way of proving goal, as a list of binding lists
(define (prove goal bindings db)
  (if (eq? bindings fail)
      '()
      (append-map
        (lambda (clause)
          (let* ((c (rename-clause clause))
                 (b (unify goal (clause-head c) bindings)))
            (if (eq? b fail)
                '()
                (prove-all (clause-body c) b db))))
        db)))

;; every way of proving all the goals, left to right
(define (prove-all goals bindings db)
  (cond ((eq? bindings fail) '())
        ((null? goals) (list bindings))
        (else (append-map (lambda (b) (prove-all (cdr goals) b db))
                          (prove (car goals) bindings db)))))

;; ---- printing

(define (say x) (format #t "=> ~a\n" x))

;; the query's own variables, resolved through the bindings and printed sorted
(define (answer-for query bindings)
  (let ((vars (reverse (variables-in query))))
    (if (null? vars)
        "yes"
        (let ((pairs (map (lambda (v) (list v (subst-bindings bindings v)))
                          (sort vars (lambda (a b)
                                       (string<? (symbol->string a) (symbol->string b)))))))
          (format #f "~a" pairs)))))

;; every solution to a query, one line each, or "fail" when there are none
(define (say-query query db)
  (let ((solutions (prove-all (list query) no-bindings db)))
    (if (null? solutions)
        (say "fail")
        (for-each (lambda (b) (say (answer-for query b))) solutions))))

;; ---- the database: a small family tree, and list membership

(define db
  '(;; facts
    ((parent tom bob))
    ((parent tom liz))
    ((parent bob ann))
    ((parent bob pat))
    ((parent pat jim))
    ((female liz))
    ((female ann))
    ((female pat))
    ((male tom))
    ((male bob))
    ((male jim))
    ;; rules
    ((grandparent ?x ?z) (parent ?x ?y) (parent ?y ?z))
    ((sibling ?x ?y) (parent ?p ?x) (parent ?p ?y))
    ((mother ?x ?y) (parent ?x ?y) (female ?x))
    ((ancestor ?x ?y) (parent ?x ?y))
    ((ancestor ?x ?y) (parent ?x ?z) (ancestor ?z ?y))))

;; PAIP's membership clauses — ((member ?i (?i . ?rest))) and its recursive twin — are NOT here.
;; Their heads carry a list with a variable tail, and wat's reader has no dotted pair: it reads
;; (?i . ?rest) as a three-element list whose middle element is a symbol named "." (F-059,
;; probes/paip/dotted-pattern.wat). The wat port could not express those clauses, so the oracle
;; must not depend on them either. The family tree needs no improper list and carries the
;; chapter.

;; ---- results

;; a ground query: true or not
(say-query '(parent tom bob) db)
(say-query '(parent bob tom) db)

;; one variable
(say-query '(parent tom ?who) db)
(say-query '(parent ?who ann) db)

;; no solution
(say-query '(parent ann ?who) db)

;; a rule with a join
(say-query '(grandparent tom ?who) db)
(say-query '(grandparent ?who jim) db)

;; a rule that needs two goals to agree
(say-query '(mother ?who pat) db)
(say-query '(mother ?m ?c) db)

;; sibling, which finds each pair twice over and each child with itself
(say-query '(sibling ann ?who) db)

;; recursion: every ancestor, through the recursive clause
(say-query '(ancestor tom ?who) db)
(say-query '(ancestor ?who jim) db)

;; two variables at once
(say-query '(grandparent ?g ?c) db)

;; a goal whose rule needs its variables renamed apart: ancestor calls itself, and the second
;; use of the clause must not collide with the first
(say-query '(ancestor ?a ?d) db)
