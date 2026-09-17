;; oracle/sicp/ch54-explicit-control.scm: our own Scheme on the topic of SICP §5.4-5.5, the
;; EXPLICIT-CONTROL evaluator and the COMPILER -- the same language run two ways, so that the
;; cost of interpretation can be counted rather than argued. Our code and our examples.
;;
;; §5.4 turns the metacircular evaluator into a register machine: the recursion that was the host's
;; becomes an explicit `continue` register and an explicit stack. §5.5 then COMPILES an expression
;; into a straight-line instruction sequence, so the interpreter's dispatch happens once, at
;; compile time, instead of on every evaluation.
;;
;; The number that matters is the last pair: the same expression, interpreted and compiled, with
;; the machine steps counted both ways.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- the language: (const n) (var x) (if a b c) (lambda (x) body) (app f a) (prim op a b) ---
(define (tag e) (car e))

;; --- §5.4: the explicit-control evaluator, with an explicit continue and stack ---
;; state: exp, env, val, continue, stack, steps
(define (ec-eval exp env)
  (let loop ((todo (list (list 'eval exp env))) (vals '()) (steps 0))
    (if (null? todo)
        (cons (car vals) steps)
        (let ((task (car todo)) (rest (cdr todo)) (n (+ steps 1)))
          (cond
            ((eq? (car task) 'eval)
             (let ((e (cadr task)) (v (caddr task)))
               (cond
                 ((eq? (tag e) 'const) (loop rest (cons (cadr e) vals) n))
                 ((eq? (tag e) 'var) (loop rest (cons (cdr (assq (cadr e) v)) vals) n))
                 ((eq? (tag e) 'if)
                  (loop (cons (list 'eval (cadr e) v) (cons (list 'ifk (caddr e) (cadddr e) v) rest)) vals n))
                 ((eq? (tag e) 'lambda) (loop rest (cons (list 'closure (cadr e) (caddr e) v) vals) n))
                 ((eq? (tag e) 'prim)
                  (loop (cons (list 'eval (caddr e) v)
                              (cons (list 'eval (cadddr e) v)
                                    (cons (list 'primk (cadr e)) rest))) vals n))
                 ((eq? (tag e) 'app)
                  (loop (cons (list 'eval (cadr e) v)
                              (cons (list 'eval (caddr e) v)
                                    (cons (list 'appk) rest))) vals n))
                 (else (error "bad exp" e)))))
            ((eq? (car task) 'ifk)
             (let ((c (car vals)))
               (loop (cons (list 'eval (if (not (eq? c #f)) (cadr task) (caddr task)) (cadddr task)) rest)
                     (cdr vals) n)))
            ((eq? (car task) 'primk)
             (let ((b (car vals)) (a (cadr vals)))
               (loop rest (cons (apply-prim (cadr task) a b) (cddr vals)) n)))
            ((eq? (car task) 'appk)
             (let* ((arg (car vals)) (f (cadr vals)))
               (loop (cons (list 'eval (caddr f) (cons (cons (car (cadr f)) arg) (cadddr f))) rest)
                     (cddr vals) n)))
            (else (error "bad task")))))))

(define (apply-prim op a b)
  (cond ((eq? op '+) (+ a b)) ((eq? op '-) (- a b)) ((eq? op '*) (* a b))
        ((eq? op '=) (= a b)) ((eq? op '<) (< a b)) (else (error "bad op"))))

(define (E e) (car (ec-eval e '())))
(define (S e) (cdr (ec-eval e '())))

(show (E '(const 5)))
(show (E '(prim + (const 1) (const 2))))
(show (E '(prim * (const 3) (prim + (const 2) (const 2)))))
(show (E '(if (prim < (const 1) (const 2)) (const 10) (const 20))))
(show (E '(if (prim < (const 2) (const 1)) (const 10) (const 20))))
(show (E '(app (lambda (x) (prim * (var x) (var x))) (const 7))))
(show (E '(app (lambda (x) (app (lambda (y) (prim + (var x) (var y))) (const 10))) (const 5))))

;; --- §5.5: the compiler. One pass over the expression emits a flat instruction list. ---
;; instructions: (push n) (lookup x) (prim op) (jump-if-false k) (jump k) (close params body) (call)
(define (compile-exp e)
  (cond ((eq? (tag e) 'const) (list (list 'push (cadr e))))
        ((eq? (tag e) 'var) (list (list 'lookup (cadr e))))
        ((eq? (tag e) 'prim)
         (append (compile-exp (caddr e)) (compile-exp (cadddr e)) (list (list 'prim (cadr e)))))
        ((eq? (tag e) 'lambda) (list (list 'close (cadr e) (compile-exp (caddr e)))))
        ((eq? (tag e) 'app) (append (compile-exp (cadr e)) (compile-exp (caddr e)) (list (list 'call))))
        ((eq? (tag e) 'if)
         (let* ((c (compile-exp (cadr e))) (t (compile-exp (caddr e))) (f (compile-exp (cadddr e))))
           (append c (list (list 'jump-if-false (+ 1 (length t)))) t (list (list 'jump (length f))) f)))
        (else (error "cannot compile" e))))

;; a tiny stack machine for the compiled code
(define (vm code env)
  (let loop ((pc 0) (stack '()) (steps 0))
    (if (>= pc (length code))
        (cons (car stack) steps)
        (let ((i (list-ref code pc)) (n (+ steps 1)))
          (cond ((eq? (car i) 'push) (loop (+ pc 1) (cons (cadr i) stack) n))
                ((eq? (car i) 'lookup) (loop (+ pc 1) (cons (cdr (assq (cadr i) env)) stack) n))
                ((eq? (car i) 'prim)
                 (loop (+ pc 1) (cons (apply-prim (cadr i) (cadr stack) (car stack)) (cddr stack)) n))
                ((eq? (car i) 'close) (loop (+ pc 1) (cons (list 'code (cadr i) (caddr i) env) stack) n))
                ((eq? (car i) 'call)
                 (let* ((arg (car stack)) (f (cadr stack))
                        (r (vm (caddr f) (cons (cons (car (cadr f)) arg) (cadddr f)))))
                   (loop (+ pc 1) (cons (car r) (cddr stack)) (+ n (cdr r)))))
                ((eq? (car i) 'jump-if-false)
                 (if (eq? (car stack) #f) (loop (+ pc 1 (cadr i)) (cdr stack) n) (loop (+ pc 1) (cdr stack) n)))
                ((eq? (car i) 'jump) (loop (+ pc 1 (cadr i)) stack n))
                (else (error "bad instruction" i)))))))

(define (C e) (car (vm (compile-exp e) '())))
(define (CS e) (cdr (vm (compile-exp e) '())))

(show (C '(const 5)))
(show (C '(prim + (const 1) (const 2))))
(show (C '(prim * (const 3) (prim + (const 2) (const 2)))))
(show (C '(if (prim < (const 1) (const 2)) (const 10) (const 20))))
(show (C '(if (prim < (const 2) (const 1)) (const 10) (const 20))))
(show (C '(app (lambda (x) (prim * (var x) (var x))) (const 7))))

;; --- the two agree, and the compiled code takes fewer steps ---
(define bench '(app (lambda (x) (prim * (var x) (prim + (var x) (const 1)))) (const 6)))
(show (E bench))
(show (C bench))
(show (= (E bench) (C bench)))
(show (S bench))
(show (CS bench))
(show (< (CS bench) (S bench)))
(show (length (compile-exp bench)))
