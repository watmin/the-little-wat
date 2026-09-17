;; oracle/sicp/ch23-symbolic-data.scm: our own Scheme on the topic of SICP §2.3, symbolic data:
;; quotation, symbolic differentiation, three representations of a set, and Huffman encoding
;; trees. Our code and our examples, not the book's text.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- symbolic differentiation: the expression is DATA, and the rules are structural ---
(define (variable? x) (symbol? x))
(define (same-variable? v1 v2) (and (variable? v1) (variable? v2) (eq? v1 v2)))
(define (=number? exp num) (and (number? exp) (= exp num)))

(define (make-sum a1 a2)
  (cond ((=number? a1 0) a2)
        ((=number? a2 0) a1)
        ((and (number? a1) (number? a2)) (+ a1 a2))
        (else (list '+ a1 a2))))
(define (make-product m1 m2)
  (cond ((or (=number? m1 0) (=number? m2 0)) 0)
        ((=number? m1 1) m2)
        ((=number? m2 1) m1)
        ((and (number? m1) (number? m2)) (* m1 m2))
        (else (list '* m1 m2))))

(define (sum? x) (and (pair? x) (eq? (car x) '+)))
(define (addend s) (cadr s))
(define (augend s) (caddr s))
(define (product? x) (and (pair? x) (eq? (car x) '*)))
(define (multiplier p) (cadr p))
(define (multiplicand p) (caddr p))

(define (deriv exp var)
  (cond ((number? exp) 0)
        ((variable? exp) (if (same-variable? exp var) 1 0))
        ((sum? exp) (make-sum (deriv (addend exp) var) (deriv (augend exp) var)))
        ((product? exp)
         (make-sum (make-product (multiplier exp) (deriv (multiplicand exp) var))
                   (make-product (deriv (multiplier exp) var) (multiplicand exp))))
        (else (error "unknown expression"))))

(show (deriv '(+ x 3) 'x))
(show (deriv '(* x y) 'x))
(show (deriv '(* (* x y) (+ x 3)) 'x))
(show (deriv '(+ x x) 'x))
(show (deriv '(* x x) 'x))
(show (deriv 5 'x))
(show (deriv 'y 'x))
;; the simplifying constructors are what keep the answers readable
(show (make-sum 0 'x))
(show (make-product 1 'x))
(show (make-product 0 'x))
(show (make-sum 2 3))

;; --- sets, three ways, all with the same interface ---
;; 1. unordered list
(define (element-of-set? x set)
  (cond ((null? set) #f) ((= x (car set)) #t) (else (element-of-set? x (cdr set)))))
(define (adjoin-set x set) (if (element-of-set? x set) set (cons x set)))
(define (intersection-set s1 s2)
  (cond ((or (null? s1) (null? s2)) '())
        ((element-of-set? (car s1) s2) (cons (car s1) (intersection-set (cdr s1) s2)))
        (else (intersection-set (cdr s1) s2))))

(show (element-of-set? 3 '(1 2 3 4)))
(show (element-of-set? 9 '(1 2 3 4)))
(show (adjoin-set 5 '(1 2 3)))
(show (adjoin-set 2 '(1 2 3)))
(show (intersection-set '(1 2 3 4) '(3 4 5 6)))

;; 2. ORDERED list: element-of-set? can stop early
(define (element-of-oset? x set)
  (cond ((null? set) #f) ((= x (car set)) #t) ((< x (car set)) #f)
        (else (element-of-oset? x (cdr set)))))
(define (intersection-oset s1 s2)
  (if (or (null? s1) (null? s2)) '()
      (let ((x1 (car s1)) (x2 (car s2)))
        (cond ((= x1 x2) (cons x1 (intersection-oset (cdr s1) (cdr s2))))
              ((< x1 x2) (intersection-oset (cdr s1) s2))
              (else (intersection-oset s1 (cdr s2)))))))

(show (element-of-oset? 3 '(1 2 3 4)))
(show (element-of-oset? 9 '(1 2 3 4)))
(show (intersection-oset '(1 2 3 4) '(3 4 5 6)))

;; 3. binary TREE, so lookup is logarithmic
(define (entry tree) (car tree))
(define (left-branch tree) (cadr tree))
(define (right-branch tree) (caddr tree))
(define (make-tree entry left right) (list entry left right))
(define (element-of-tset? x set)
  (cond ((null? set) #f)
        ((= x (entry set)) #t)
        ((< x (entry set)) (element-of-tset? x (left-branch set)))
        (else (element-of-tset? x (right-branch set)))))
(define (adjoin-tset x set)
  (cond ((null? set) (make-tree x '() '()))
        ((= x (entry set)) set)
        ((< x (entry set)) (make-tree (entry set) (adjoin-tset x (left-branch set)) (right-branch set)))
        (else (make-tree (entry set) (left-branch set) (adjoin-tset x (right-branch set))))))
(define (tree->list tree)
  (if (null? tree) '()
      (append (tree->list (left-branch tree)) (cons (entry tree) (tree->list (right-branch tree))))))

(define t1 (adjoin-tset 1 (adjoin-tset 9 (adjoin-tset 3 (adjoin-tset 7 (adjoin-tset 5 '()))))))
(show (element-of-tset? 3 t1))
(show (element-of-tset? 4 t1))
(show (tree->list t1))

;; --- Huffman trees: decoding, and that the encoding respects the weights ---
(define (make-leaf symbol weight) (list 'leaf symbol weight))
(define (leaf? object) (eq? (car object) 'leaf))
(define (symbol-leaf x) (cadr x))
(define (weight-leaf x) (caddr x))
(define (make-code-tree left right)
  (list left right (append (symbols left) (symbols right)) (+ (weight left) (weight right))))
(define (left-b tree) (car tree))
(define (right-b tree) (cadr tree))
(define (symbols tree) (if (leaf? tree) (list (symbol-leaf tree)) (caddr tree)))
(define (weight tree) (if (leaf? tree) (weight-leaf tree) (cadddr tree)))

(define (choose-branch bit branch)
  (cond ((= bit 0) (left-b branch)) ((= bit 1) (right-b branch)) (else (error "bad bit"))))
(define (decode bits tree)
  (define (decode-1 bits current)
    (if (null? bits) '()
        (let ((next (choose-branch (car bits) current)))
          (if (leaf? next)
              (cons (symbol-leaf next) (decode-1 (cdr bits) tree))
              (decode-1 (cdr bits) next)))))
  (decode-1 bits tree))

(define sample-tree
  (make-code-tree (make-leaf 'a 4)
                  (make-code-tree (make-leaf 'b 2)
                                  (make-code-tree (make-leaf 'd 1) (make-leaf 'c 1)))))
(show (weight sample-tree))
(show (symbols sample-tree))
(show (decode '(0 1 1 0 0 1 0 1 0 1 1 1 0) sample-tree))
(show (decode '(0 0 0) sample-tree))
(show (decode '(1 1 1 1 1 0) sample-tree))
