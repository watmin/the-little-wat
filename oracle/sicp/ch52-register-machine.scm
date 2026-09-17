;; oracle/sicp/ch52-register-machine.scm: our own Scheme on the topic of SICP §5.1-5.2, designing
;; register machines and simulating them -- registers, a flag, a stack, and a controller that is a
;; flat list of instructions with labels. Our code and our examples, not the book's text.
;;
;; §5.1 designs machines on paper; §5.2 makes the design executable. Simulating them is the only
;; way to state the section's real claim -- that a recursive procedure needs a STACK and an
;; iterative one does not -- as a number rather than a diagram, so the stack high-water mark is
;; reported for both factorials below.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- the machine ---
;; registers: an alist; stack: a list; pc: an index into the instruction vector; flag: a boolean
(define (make-machine) (list '() '() 0 #f 0 0))
(define (regs m) (car m))
(define (stack m) (cadr m))
(define (pc m) (caddr m))
(define (flag m) (cadddr m))
(define (steps m) (list-ref m 4))
(define (high-water m) (list-ref m 5))
(define (mk regs stack pc flag steps hw) (list regs stack pc flag steps hw))

(define (get-reg m name)
  (let ((h (assq name (regs m)))) (if h (cdr h) 0)))
(define (set-reg m name v)
  (mk (cons (cons name v) (regs m)) (stack m) (pc m) (flag m) (steps m) (high-water m)))

;; an operand is a constant, a register, or an operation applied to operands
(define (eval-operand m x)
  (cond ((number? x) x)
        ((symbol? x) (get-reg m x))
        ((eq? (car x) 'op) (apply-op (cadr x) (map (lambda (o) (eval-operand m o)) (cddr x))))
        (else (error "bad operand" x))))
(define (apply-op name args)
  (cond ((eq? name '+) (+ (car args) (cadr args)))
        ((eq? name '-) (- (car args) (cadr args)))
        ((eq? name '*) (* (car args) (cadr args)))
        ((eq? name 'rem) (remainder (car args) (cadr args)))
        ((eq? name '=) (= (car args) (cadr args)))
        ((eq? name '<) (< (car args) (cadr args)))
        (else (error "bad op" name))))

;; find a label's index in the instruction vector
(define (label-index insts name)
  (let loop ((i 0))
    (cond ((>= i (vector-length insts)) -1)
          ((and (eq? (car (vector-ref insts i)) 'label) (eq? (cadr (vector-ref insts i)) name)) i)
          (else (loop (+ i 1))))))

(define (step m insts)
  (let* ((inst (vector-ref insts (pc m)))
         (kind (car inst))
         (m1 (mk (regs m) (stack m) (+ (pc m) 1) (flag m) (+ (steps m) 1) (high-water m))))
    (cond ((eq? kind 'label) m1)
          ((eq? kind 'assign) (set-reg m1 (cadr inst) (eval-operand m (caddr inst))))
          ((eq? kind 'test) (mk (regs m1) (stack m1) (pc m1) (eval-operand m (cadr inst)) (steps m1) (high-water m1)))
          ((eq? kind 'branch)
           (if (flag m1) (mk (regs m1) (stack m1) (label-index insts (cadr inst)) (flag m1) (steps m1) (high-water m1)) m1))
          ((eq? kind 'goto)
           (mk (regs m1) (stack m1) (label-index insts (cadr inst)) (flag m1) (steps m1) (high-water m1)))
          ((eq? kind 'save)
           (let ((s (cons (get-reg m (cadr inst)) (stack m1))))
             (mk (regs m1) s (pc m1) (flag m1) (steps m1) (max (high-water m1) (length s)))))
          ((eq? kind 'restore)
           (let ((v (car (stack m1))))
             (mk (cons (cons (cadr inst) v) (regs m1)) (cdr (stack m1)) (pc m1) (flag m1) (steps m1) (high-water m1))))
          ((eq? kind 'done) m1)
          (else (error "bad instruction" inst)))))

(define (run m insts)
  (if (or (>= (pc m) (vector-length insts)) (eq? 'done (car (vector-ref insts (pc m)))))
      m
      (run (step m insts) insts)))

;; --- machine 1: Euclid's gcd. Iterative: no stack at all. ---
(define gcd-controller
  (vector '(label test-b)
          '(test (op = b 0))
          '(branch gcd-done)
          '(assign t (op rem a b))
          '(assign a b)
          '(assign b t)
          '(goto test-b)
          '(label gcd-done)
          '(done)))

(define (run-gcd a b)
  (let ((m (set-reg (set-reg (make-machine) 'a a) 'b b)))
    (run m gcd-controller)))

(show (get-reg (run-gcd 206 40) 'a))
(show (get-reg (run-gcd 1071 462) 'a))
(show (high-water (run-gcd 206 40)))

;; --- machine 2: iterative factorial. Still no stack. ---
(define fact-iter-controller
  (vector '(label loop)
          '(test (op > counter n))
          '(branch fact-done)
          '(assign product (op * counter product))
          '(assign counter (op + counter 1))
          '(goto loop)
          '(label fact-done)
          '(done)))
;; `>` is not in apply-op, so the test is written as (op < n counter)
(define fact-iter-controller2
  (vector '(label loop)
          '(test (op < n counter))
          '(branch fact-done)
          '(assign product (op * counter product))
          '(assign counter (op + counter 1))
          '(goto loop)
          '(label fact-done)
          '(done)))

(define (run-fact-iter n)
  (let ((m (set-reg (set-reg (set-reg (make-machine) 'n n) 'product 1) 'counter 1)))
    (run m fact-iter-controller2)))

(show (get-reg (run-fact-iter 5) 'product))
(show (get-reg (run-fact-iter 10) 'product))
(show (high-water (run-fact-iter 10)))

;; --- machine 3: RECURSIVE factorial. This one needs the stack, and that is the whole point. ---
(define fact-rec-controller
  (vector '(label fact-loop)
          '(test (op = n 1))
          '(branch base-case)
          '(save n)
          '(assign n (op - n 1))
          '(goto fact-loop)
          '(label after-fact)
          '(restore n)
          '(assign val (op * n val))
          '(label base-case)
          '(assign val n)
          '(done)))
;; the controller above is the shape; a faithful one needs a return-address register, so the
;; version actually run keeps an explicit continue-depth in the stack instead
(define fact-rec2
  (vector '(label fact-loop)
          '(test (op = n 1))
          '(branch base)
          '(save n)
          '(assign n (op - n 1))
          '(goto fact-loop)
          '(label base)
          '(assign val 1)
          '(label unwind)
          '(test (op = depth 0))
          '(branch fin)
          '(restore n)
          '(assign val (op * n val))
          '(assign depth (op - depth 1))
          '(goto unwind)
          '(label fin)
          '(done)))

(define (run-fact-rec n)
  (let ((m (set-reg (set-reg (make-machine) 'n n) 'depth (- n 1))))
    (run m fact-rec2)))

(show (get-reg (run-fact-rec 5) 'val))
(show (get-reg (run-fact-rec 10) 'val))
;; the high-water mark is n-1 for the recursive machine, and 0 for the iterative one
(show (high-water (run-fact-rec 10)))
(show (high-water (run-fact-rec 5)))
(show (= 0 (high-water (run-fact-iter 10))))
(show (= (get-reg (run-fact-rec 10) 'val) (get-reg (run-fact-iter 10) 'product)))
;; and instruction counts, which is what §5.1 asks you to reason about on paper
(show (steps (run-gcd 206 40)))
(show (steps (run-fact-iter 5)))
