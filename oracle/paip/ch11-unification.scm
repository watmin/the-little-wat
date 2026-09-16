;; oracle/paip/ch11-unification.scm: the expected answers for paip/ch11-unification.wat.
;;
;; Our own Scheme on chapter 11's topic — unification over quoted S-expressions — written from
;; the algorithm, not from Norvig's code, which is neither read nor copied here. The same rule
;; the Pie and malt ports follow.
;;
;; A pattern is an ordinary quoted S-expression in which a variable is a symbol beginning with
;; a question mark: ?x. That is the whole point of the chapter: patterns are DATA, not a typed
;; term language. A binding list maps a variable to a term, and unify answers a binding list or
;; the failure marker.
;;
;; Printing: a binding list is printed CANONICALLY — sorted by variable name, each binding as
;; (?var value) — rather than as Scheme's dotted pairs. Scheme would print ((?x . a)), and a
;; list-valued binding would splice into (?x g ?y), which says more about Scheme's printer than
;; about unification; and the raw order would pin the answer to this implementation's cons
;; order. Sorting and spelling each binding as a two-element list keeps every expected string
;; something an implementation can reproduce from the algorithm alone.
;;
;; Every line printed after "=> " is a result the wat port must print, in order.
;;
;; Run: tools/paip-oracle.sh ch11-unification

(use-modules (ice-9 format) (srfi srfi-1))

(define fail 'fail)
(define no-bindings '())

(define (variable? x)
  (and (symbol? x)
       (let ((s (symbol->string x)))
         (and (> (string-length s) 0)
              (char=? (string-ref s 0) #\?)))))

(define (get-binding var bindings)
  (assq var bindings))

(define (binding-val binding) (cdr binding))

(define (lookup var bindings)
  (let ((b (get-binding var bindings)))
    (if b (binding-val b) #f)))

(define (extend-bindings var val bindings)
  (cons (cons var val) bindings))

;; Does var occur anywhere inside x, once x's own bindings are followed?
(define (occurs-in? var x bindings)
  (cond ((eq? var x) #t)
        ((and (variable? x) (get-binding x bindings))
         (occurs-in? var (lookup x bindings) bindings))
        ((pair? x) (or (occurs-in? var (car x) bindings)
                       (occurs-in? var (cdr x) bindings)))
        (else #f)))

(define (unify-variable var x bindings)
  (cond ((get-binding var bindings)
         (unify (lookup var bindings) x bindings))
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

;; Replace every bound variable in x by what it is bound to, all the way down.
(define (subst-bindings bindings x)
  (cond ((eq? bindings fail) fail)
        ((null? bindings) x)
        ((and (variable? x) (get-binding x bindings))
         (subst-bindings bindings (lookup x bindings)))
        ((pair? x) (cons (subst-bindings bindings (car x))
                         (subst-bindings bindings (cdr x))))
        (else x)))

;; The unifier's answer: the two patterns made identical, or fail.
(define (unifier x y)
  (let ((b (unify x y no-bindings)))
    (if (eq? b fail) fail (subst-bindings b x))))

;; ---- printing

(define (say x) (format #t "=> ~a\n" x))

(define (say-bool b) (say (if b "true" "false")))

;; a binding list, sorted by variable name, each binding as (?var value)
(define (say-bindings b)
  (if (eq? b fail)
      (say "fail")
      (let* ((sorted (sort b (lambda (p q)
                               (string<? (symbol->string (car p))
                                         (symbol->string (car q))))))
             (pairs (map (lambda (p) (list (car p) (cdr p))) sorted)))
        (say pairs))))

(define (say-term x) (say (if (eq? x fail) "fail" x)))

;; ---- results

;; what counts as a variable
(say-bool (variable? '?x))
(say-bool (variable? 'x))
(say-bool (variable? '?))
(say-bool (variable? 42))

;; atoms unify with themselves and nothing else
(say-bindings (unify 'a 'a no-bindings))
(say-bindings (unify 'a 'b no-bindings))
(say-bindings (unify 1 1 no-bindings))

;; a variable takes the other side
(say-bindings (unify '?x 'a no-bindings))
(say-bindings (unify 'a '?x no-bindings))
(say-bindings (unify '?x '?y no-bindings))

;; lists unify element by element
(say-bindings (unify '(?x + 1) '(2 + ?y) no-bindings))
(say-bindings (unify '(?x ?y) '(?y ?x) no-bindings))
(say-bindings (unify '(f ?x) '(f a) no-bindings))
(say-bindings (unify '(f ?x) '(g a) no-bindings))
(say-bindings (unify '(f ?x ?y) '(f a) no-bindings))

;; a variable bound twice must agree
(say-bindings (unify '(?x ?x) '(a a) no-bindings))
(say-bindings (unify '(?x ?x) '(a b) no-bindings))

;; nesting
(say-bindings (unify '(?x (f ?y)) '((g ?y) (f b)) no-bindings))

;; the occurs check: ?x cannot stand for something containing ?x
(say-bindings (unify '?x '(f ?x) no-bindings))
(say-bindings (unify '(?x ?y) '((f ?y) ?x) no-bindings))

;; substituting a binding list through a pattern
(say-term (subst-bindings (unify '(?x + 1) '(2 + ?y) no-bindings) '(?x and ?y)))
(say-term (subst-bindings (unify '(?x ?y) '((f a) b) no-bindings) '(?x ?y ?z)))

;; the unifier: both patterns made one
(say-term (unifier '(?x + 1) '(2 + ?y)))
(say-term (unifier '(?x ?y a) '(?y ?x ?x)))
(say-term (unifier '(f ?x) '(g a)))
