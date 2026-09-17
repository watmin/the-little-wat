;; oracle/paip/ch22-scheme-interpreter.scm: our own Scheme on the topic of PAIP chapter 22, a
;; Scheme interpreter -- written in CONTINUATION-PASSING STYLE so that `call/cc` is available to
;; the interpreted language. Our code and our examples; Norvig's own code is not read or copied.
;;
;; guile has call/cc of its own, and it is deliberately NOT used: the interpreter below implements
;; call/cc from its own explicit continuations, exactly as the wat port must, so the two are doing
;; the same work and can be compared.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a value: a number, a boolean, a closure, a PRIMITIVE, or a captured CONTINUATION
(define (closure? v) (and (pair? v) (eq? (car v) 'closure)))
(define (cont? v) (and (pair? v) (eq? (car v) 'cont)))
(define (prim? v) (and (pair? v) (eq? (car v) 'prim)))

(define (lookup x env) (let ((h (assq x env))) (if h (cdr h) 'unbound)))

(define (ev e env k)
  (cond ((number? e) (k e))
        ((symbol? e) (k (lookup e env)))
        ((eq? (car e) 'if)
         (ev (cadr e) env (lambda (c) (if (not (eq? c #f)) (ev (caddr e) env k) (ev (cadddr e) env k)))))
        ((eq? (car e) 'lambda) (k (list 'closure (cadr e) (caddr e) env)))
        ;; call/cc: hand the current continuation to the argument, packaged as a value
        ((eq? (car e) 'call/cc)
         (ev (cadr e) env (lambda (f) (apply-proc f (list (list 'cont k)) k))))
        (else (ev (car e) env
                  (lambda (f) (ev-args (cdr e) env (lambda (as) (apply-proc f as k))))))))

(define (ev-args es env k)
  (if (null? es) (k '())
      (ev (car es) env (lambda (v) (ev-args (cdr es) env (lambda (vs) (k (cons v vs))))))))

(define (apply-proc f args k)
  (cond ((prim? f) (k (apply-prim (cadr f) args)))
        ((closure? f) (ev (caddr f) (append (map cons (cadr f) args) (cadddr f)) k))
        ;; applying a CONTINUATION abandons the current one: that is the whole of the feature
        ((cont? f) ((cadr f) (car args)))
        (else 'not-callable)))

(define (apply-prim name args)
  (cond ((eq? name '+) (+ (car args) (cadr args)))
        ((eq? name '-) (- (car args) (cadr args)))
        ((eq? name '*) (* (car args) (cadr args)))
        ((eq? name '=) (= (car args) (cadr args)))
        ((eq? name 'zero?) (= 0 (car args)))
        (else 'bad-prim)))

(define global
  (list (cons '+ '(prim +)) (cons '- '(prim -)) (cons '* '(prim *))
        (cons '= '(prim =)) (cons 'zero? '(prim zero?))))

(define (E e) (ev e global (lambda (v) v)))

;; --- ordinary evaluation still works ---
(show (E '5))
(show (E '(+ 1 2)))
(show (E '(if (= 1 1) 10 20)))
(show (E '((lambda (x) (* x x)) 7)))

;; --- call/cc, not used: the continuation is captured and ignored ---
(show (E '(call/cc (lambda (k) 42))))
(show (E '(+ 1 (call/cc (lambda (k) 10)))))

;; --- call/cc, used: an ESCAPE out of the middle of an expression ---
(show (E '(call/cc (lambda (k) (k 42)))))
(show (E '(+ 1 (call/cc (lambda (k) (k 10))))))
;; the escape abandons the rest: the (* 100 ...) never happens
(show (E '(+ 1 (call/cc (lambda (k) (* 100 (k 10)))))))
;; two escapes from nested positions
(show (E '(+ 1 (+ 2 (call/cc (lambda (k) (k 30)))))))

;; --- the classic: short-circuit out of a recursion ---
;; product of 4*3*0*2 -- the escape means the outer multiplications never run
(show (E '(call/cc (lambda (return)
            ((lambda (f) (f f 4))
             (lambda (f n) (if (zero? n) (return 0) (* n (f f (- n 1)))))))))) 
;; the same function WITHOUT the escape, to show the escape is what changed the answer
(show (E '((lambda (f) (f f 4)) (lambda (f n) (if (zero? n) 1 (* n (f f (- n 1))))))))
;; a continuation is a first-class VALUE: it can be passed to an ordinary procedure
(show (E '(+ 1 (call/cc (lambda (k) ((lambda (c) (c 5)) k))))))
