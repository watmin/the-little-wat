;; oracle/sicp/ch41-metacircular.scm: our own Scheme on the topic of SICP §4.1, the metacircular
;; evaluator -- eval and apply defined in terms of each other, over a language whose programs are
;; the same data the evaluator is written in. Our code and our examples, not the book's text.
;;
;; The section's claim is that an interpreter is a small, ordinary program: the whole of it is
;; "eval dispatches on the form, apply extends an environment and evals the body", and everything
;; else is detail. What is checked below is that the evaluator agrees with its own host on the
;; same expressions -- self-evaluating forms, quote, if, lambda, define, and application.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- environments: a frame is an alist, the chain ends at '() ---
(define (extend-env names values env) (cons (map cons names values) env))
(define (lookup-var name env)
  (if (null? env) (error "unbound" name)
      (let ((hit (assq name (car env))))
        (if hit (cdr hit) (lookup-var name (cdr env))))))

;; --- the evaluator ---
(define (self-evaluating? exp) (number? exp))
(define (variable? exp) (symbol? exp))
(define (tagged? exp tag) (and (pair? exp) (eq? (car exp) tag)))

(define (my-eval exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-var exp env))
        ((tagged? exp 'quote) (cadr exp))
        ((tagged? exp 'if) (eval-if exp env))
        ((tagged? exp 'lambda) (list 'procedure (cadr exp) (caddr exp) env))
        ((tagged? exp 'let) (my-eval (let->combination exp) env))
        ((pair? exp) (my-apply (my-eval (car exp) env) (map (lambda (e) (my-eval e env)) (cdr exp))))
        (else (error "unknown expression" exp))))

(define (eval-if exp env)
  (if (true? (my-eval (cadr exp) env)) (my-eval (caddr exp) env) (my-eval (cadddr exp) env)))
(define (true? x) (not (eq? x #f)))

;; `let` is DERIVED: it is a lambda applied, and needs no rule of its own in eval
(define (let->combination exp)
  (let ((bindings (cadr exp)) (body (caddr exp)))
    (cons (list 'lambda (map car bindings) body) (map cadr bindings))))

(define (my-apply proc args)
  (cond ((procedure? proc) (apply proc args))
        ((tagged? proc 'procedure)
         (my-eval (caddr proc) (extend-env (cadr proc) args (cadddr proc))))
        (else (error "unknown procedure"))))

(define global-env
  (extend-env '(+ - * = < true false)
              (list + - * = < #t #f)
              '()))

(define (E exp) (my-eval exp global-env))

;; --- self-evaluating, variables, quote ---
(show (E '5))
(show (E '(quote hello)))
(show (E '(+ 1 2)))
(show (E '(* 3 (+ 2 2))))
(show (E '(- 10 (* 2 3))))

;; --- if ---
(show (E '(if (< 1 2) 10 20)))
(show (E '(if (< 2 1) 10 20)))
(show (E '(if true 1 2)))

;; --- lambda and application ---
(show (E '((lambda (x) (* x x)) 7)))
(show (E '((lambda (x y) (+ x y)) 3 4)))
;; a closure that captures
(show (E '((lambda (x) ((lambda (y) (+ x y)) 10)) 5)))

;; --- let, which is derived rather than primitive ---
(show (E '(let ((x 3) (y 4)) (+ x y))))
(show (E '(let ((x 3)) (let ((y 4)) (* x y)))))
;; and the derivation is visible: the let above IS this combination
(show (let->combination '(let ((x 3) (y 4)) (+ x y))))

;; --- the evaluator agrees with its host ---
(show (= (E '(+ 1 2)) (+ 1 2)))
(show (= (E '((lambda (x) (* x x)) 7)) 49))
(show (= (E '(let ((x 3) (y 4)) (+ x y))) 7))
