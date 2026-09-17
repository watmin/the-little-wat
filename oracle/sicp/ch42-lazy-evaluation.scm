;; oracle/sicp/ch42-lazy-evaluation.scm: our own Scheme on the topic of SICP §4.2, lazy
;; evaluation -- the same metacircular evaluator, changed in one place, so that an operand becomes
;; a THUNK and is forced only when its value is actually needed. Our code and our examples.
;;
;; The section's two demonstrations are both here: a divergent argument that is never used costs
;; nothing, and `unless` becomes definable as an ordinary procedure, which it cannot be in an
;; applicative-order language. The third thing the section raises -- that call-by-name evaluates a
;; repeated argument repeatedly, and that MEMOIZING the thunk fixes it -- is counted explicitly.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define (extend-env names values env) (cons (map cons names values) env))
(define (lookup-var name env)
  (if (null? env) (error "unbound" name)
      (let ((hit (assq name (car env))))
        (if hit (cdr hit) (lookup-var name (cdr env))))))

(define (tagged? exp tag) (and (pair? exp) (eq? (car exp) tag)))

;; a thunk is unevaluated code plus its environment; forcing runs it
(define (delay-it exp env) (list 'thunk exp env))
(define (thunk? x) (tagged? x 'thunk))
(define (force-it x) (if (thunk? x) (force-it (l-eval (cadr x) (caddr x))) x))

;; how many times was a thunk forced? counted, because the by-name/by-need difference IS the count
(define force-count 0)

(define (l-eval exp env)
  (cond ((number? exp) exp)
        ((symbol? exp) (force-it (lookup-var exp env)))
        ((tagged? exp 'if)
         (if (not (eq? (force-it (l-eval (cadr exp) env)) #f))
             (l-eval (caddr exp) env) (l-eval (cadddr exp) env)))
        ((tagged? exp 'lambda) (list 'procedure (cadr exp) (caddr exp) env))
        ((pair? exp) (l-apply (actual-value (car exp) env) (cdr exp) env))
        (else (error "unknown" exp))))

(define (actual-value exp env) (force-it (l-eval exp env)))

(define (l-apply proc operands env)
  (cond ((procedure? proc) (apply proc (map (lambda (o) (actual-value o env)) operands)))
        ((tagged? proc 'procedure)
         (l-eval (caddr proc)
                 (extend-env (cadr proc) (map (lambda (o) (delay-it o env)) operands) (cadddr proc))))
        (else (error "unknown procedure"))))

(define (counted-div a b) (set! force-count (+ force-count 1)) (if (= b 0) (error "div0") (quotient a b)))
(define (bump x) (set! force-count (+ force-count 1)) x)

(define global-env
  (extend-env '(+ - * = < / bump true false)
              (list + - * = < counted-div bump #t #f) '()))
(define (E exp) (actual-value exp global-env))

;; --- ordinary things still work ---
(show (E '(+ 1 2)))
(show (E '((lambda (x) (* x x)) 7)))
(show (E '(if (< 1 2) 10 20)))

;; --- a divergent argument that is never USED costs nothing ---
;; (try 0 (/ 1 0)) -- strict evaluation would divide by zero before try is entered
(show (E '((lambda (a b) (if (= a 0) 1 b)) 0 (/ 1 0))))
;; and when it IS used, the same expression does diverge -- so laziness is the reason, not luck
(show (E '((lambda (a b) (if (= a 0) 1 b)) 1 (/ 6 3))))

;; --- `unless` as an ordinary PROCEDURE, which applicative order cannot have ---
(show (E '((lambda (condition usual alternative) (if condition alternative usual))
           (= 1 0) 5 (/ 1 0))))

;; --- and the cost of call-by-NAME: a repeated argument is evaluated repeatedly ---
(set! force-count 0)
(show (E '((lambda (x) (+ x (+ x x))) (bump 7))))
(show force-count)
(set! force-count 0)
(show (E '((lambda (x) x) (bump 7))))
(show force-count)
(set! force-count 0)
(show (E '((lambda (x) 99) (bump 7))))
(show force-count)
