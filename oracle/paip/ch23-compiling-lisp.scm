;; oracle/paip/ch23-compiling-lisp.scm: our own Scheme on the topic of PAIP chapter 23, compiling
;; Lisp -- an expression compiled to a flat instruction sequence, and then a PEEPHOLE OPTIMIZER
;; that rewrites short windows of that sequence. Our code and our examples; Norvig's own code is
;; not read or copied.
;;
;; SICP §5.5 already compiled in this repository; the thing PAIP adds is the optimizer, so the
;; measurement here is instruction COUNT before and after, plus the proof that the two programs
;; still compute the same answer.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- the compiler: (const n) (var x) (prim op a b) (if c t f) ---
(define (comp e)
  (cond ((eq? (car e) 'const) (list (list 'const (cadr e))))
        ((eq? (car e) 'var) (list (list 'var (cadr e))))
        ((eq? (car e) 'prim) (append (comp (caddr e)) (comp (cadddr e)) (list (list 'prim (cadr e)))))
        ((eq? (car e) 'if)
         (let ((c (comp (cadr e))) (t (comp (caddr e))) (f (comp (cadddr e))))
           (append c (list (list 'jfalse (+ 1 (length t)))) t (list (list 'jump (length f))) f)))
        (else (error "cannot compile"))))

;; --- the peephole optimizer: three rewrites over a window of two ---
(define (peephole code)
  (cond ((null? code) '())
        ((null? (cdr code)) code)
        (else
         (let ((a (car code)) (b (cadr code)) (rest (cddr code)))
           (cond
             ;; two constants then an arithmetic prim: fold them
             ((and (eq? (car a) 'const) (eq? (car b) 'const)
                   (not (null? rest)) (eq? (car (car rest)) 'prim)
                   (memq (cadr (car rest)) '(+ - *)))
              (peephole (cons (list 'const (fold-op (cadr (car rest)) (cadr a) (cadr b))) (cdr rest))))
             ;; adding zero, or multiplying by one, is nothing at all
             ((and (eq? (car b) 'const) (= 0 (cadr b))
                   (not (null? rest)) (equal? (car rest) '(prim +)))
              (peephole (cons a (cdr rest))))
             ((and (eq? (car b) 'const) (= 1 (cadr b))
                   (not (null? rest)) (equal? (car rest) '(prim *)))
              (peephole (cons a (cdr rest))))
             (else (cons a (peephole (cdr code)))))))))

(define (fold-op op a b) (cond ((eq? op '+) (+ a b)) ((eq? op '-) (- a b)) (else (* a b))))

;; --- the machine ---
(define (run code env)
  (let loop ((pc 0) (stack '()))
    (if (>= pc (length code)) (car stack)
        (let ((i (list-ref code pc)))
          (cond ((eq? (car i) 'const) (loop (+ pc 1) (cons (cadr i) stack)))
                ((eq? (car i) 'var) (loop (+ pc 1) (cons (cdr (assq (cadr i) env)) stack)))
                ((eq? (car i) 'prim)
                 (loop (+ pc 1) (cons (apply-prim (cadr i) (cadr stack) (car stack)) (cddr stack))))
                ((eq? (car i) 'jfalse)
                 (if (eq? (car stack) #f) (loop (+ pc 1 (cadr i)) (cdr stack)) (loop (+ pc 1) (cdr stack))))
                ((eq? (car i) 'jump) (loop (+ pc 1 (cadr i)) stack))
                (else (error "bad instruction")))))))

(define (apply-prim op a b)
  (cond ((eq? op '+) (+ a b)) ((eq? op '-) (- a b)) ((eq? op '*) (* a b))
        ((eq? op '<) (< a b)) ((eq? op '=) (= a b)) (else (error "bad op"))))

(define env '((x . 5) (y . 3)))

;; --- plain compilation ---
(show (length (comp '(const 5))))
(show (run (comp '(const 5)) env))
(show (length (comp '(prim + (const 1) (const 2)))))
(show (run (comp '(prim + (const 1) (const 2))) env))
(show (run (comp '(prim * (var x) (var y))) env))
(show (run (comp '(if (prim < (var y) (var x)) (const 10) (const 20))) env))

;; --- the optimizer folds constants ---
(show (length (peephole (comp '(prim + (const 1) (const 2))))))
(show (run (peephole (comp '(prim + (const 1) (const 2)))) env))
;; and removes identities
(show (length (comp '(prim + (var x) (const 0)))))
(show (length (peephole (comp '(prim + (var x) (const 0))))))
(show (run (peephole (comp '(prim + (var x) (const 0)))) env))
(show (length (peephole (comp '(prim * (var x) (const 1))))))
(show (run (peephole (comp '(prim * (var x) (const 1)))) env))

;; --- a bigger expression: same answer, fewer instructions ---
(define big '(prim + (prim * (const 2) (const 3)) (prim * (var x) (const 1))))
(show (run (comp big) env))
(show (run (peephole (comp big)) env))
(show (= (run (comp big) env) (run (peephole (comp big)) env)))
(show (length (comp big)))
(show (length (peephole (comp big))))
(show (< (length (peephole (comp big))) (length (comp big))))
