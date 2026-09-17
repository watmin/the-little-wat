;; oracle/sicp/ch32-environment-model.scm: our own Scheme on the topic of SICP §3.2, the
;; ENVIRONMENT MODEL of evaluation -- a frame is a table of bindings plus a pointer to an
;; enclosing frame, a procedure is code plus the frame it was created in, and applying one makes
;; a NEW frame whose enclosing frame is the procedure's, not the caller's.
;;
;; Rather than describe the model, this builds it: frames are data here, and the results below are
;; what the model itself computes. That is the only way to show the claims that make §3.2 matter --
;; that two procedures from one maker have SEPARATE frames, and that a closure sees where it was
;; MADE and not where it was called. Our code and our examples, not the book's text.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a frame: an association list of bindings, plus the enclosing frame ('() is the global end)
(define (make-frame bindings enclosing) (list bindings enclosing))
(define (bindings f) (car f))
(define (enclosing f) (cadr f))
(define the-empty-env '())

(define (extend-env names values env) (make-frame (map cons names values) env))

;; lookup walks OUT along the chain, and stops at the first frame that binds the name
(define (lookup name env)
  (if (null? env) 'unbound
      (let ((hit (assq name (bindings env))))
        (if hit (cdr hit) (lookup name (enclosing env))))))

;; how many frames out did the name come from? this is what "lexical scoping" measures
(define (depth-of name env d)
  (if (null? env) -1
      (if (assq name (bindings env)) d (depth-of name (enclosing env) (+ d 1)))))

(define global (extend-env '(x y) '(10 20) the-empty-env))
(define inner (extend-env '(x z) '(99 5) global))

(show (lookup 'x global))
(show (lookup 'y global))
(show (lookup 'q global))
;; the inner frame SHADOWS x, and y is still reachable by walking out
(show (lookup 'x inner))
(show (lookup 'y inner))
(show (lookup 'z inner))
(show (depth-of 'x inner 0))
(show (depth-of 'y inner 0))
(show (depth-of 'q inner 0))

;; --- a procedure is code plus the frame it was MADE in ---
(define (make-procedure params body env) (list 'proc params body env))
(define (proc-params p) (cadr p))
(define (proc-body p) (caddr p))
(define (proc-env p) (cadddr p))

;; applying it makes a new frame whose enclosing frame is the PROCEDURE'S, not the caller's
(define (apply-proc p args) (extend-env (proc-params p) args (proc-env p)))

;; (lambda (a) ...) created in `global`, then applied from inside `inner`
(define p1 (make-procedure '(a) 'body global))
(define call-frame (apply-proc p1 '(7)))

(show (lookup 'a call-frame))
;; x resolves to the GLOBAL 10, not to inner's 99, though the call happened "inside" inner
(show (lookup 'x call-frame))
(show (depth-of 'x call-frame 0))

;; --- two procedures from one maker have SEPARATE frames ---
;; (define (make-counter start) (lambda () start)) -- called twice with different starts
(define (make-counter start) (make-procedure '() 'body (extend-env '(start) (list start) global)))
(define c1 (make-counter 100))
(define c2 (make-counter 200))

(show (lookup 'start (proc-env c1)))
(show (lookup 'start (proc-env c2)))
(show (= (lookup 'start (proc-env c1)) (lookup 'start (proc-env c2))))
;; and both still see the global frame behind their own
(show (lookup 'y (proc-env c1)))
(show (depth-of 'start (proc-env c1) 0))
(show (depth-of 'y (proc-env c1) 0))
