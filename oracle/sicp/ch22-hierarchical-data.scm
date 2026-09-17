;; oracle/sicp/ch22-hierarchical-data.scm: our own Scheme on the topic of SICP §2.2, hierarchical
;; data and the CLOSURE PROPERTY -- the ability of a combining means to produce things that can
;; themselves be combined -- plus sequences as a conventional interface, and nested mappings.
;; Our code and our examples, not the book's text.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- lists ---
(define (my-length items) (if (null? items) 0 (+ 1 (my-length (cdr items)))))
(define (my-append a b) (if (null? a) b (cons (car a) (my-append (cdr a) b))))
(define (my-reverse items)
  (define (iter rest acc) (if (null? rest) acc (iter (cdr rest) (cons (car rest) acc))))
  (iter items '()))

(show (my-length '(1 2 3 4 5)))
(show (my-append '(1 2 3) '(4 5)))
(show (my-reverse '(1 2 3 4 5)))

;; --- the CLOSURE PROPERTY: a list whose elements may themselves be lists ---
(define (count-leaves t)
  (cond ((null? t) 0)
        ((not (pair? t)) 1)
        (else (+ (count-leaves (car t)) (count-leaves (cdr t))))))

(show (count-leaves '((1 2) (3 4) 5)))
(show (count-leaves '(1 (2 (3 (4 (5)))))))
(show (my-length '((1 2) (3 4) 5)))

;; fringe: every leaf, left to right, however deeply nested
(define (fringe t)
  (cond ((null? t) '())
        ((not (pair? t)) (list t))
        (else (my-append (fringe (car t)) (fringe (cdr t))))))
(show (fringe '((1 2) (3 4) 5)))
(show (fringe '(1 (2 (3 (4 (5)))))))

;; deep-reverse: reverse at every level
(define (deep-reverse t)
  (if (not (pair? t)) t (my-reverse (map deep-reverse t))))
(show (deep-reverse '((1 2) (3 4))))

;; scale a whole tree, however shaped
(define (scale-tree t factor)
  (cond ((null? t) '())
        ((not (pair? t)) (* t factor))
        (else (cons (scale-tree (car t) factor) (scale-tree (cdr t) factor)))))
(show (scale-tree '((1 2) (3 4) 5) 10))

;; --- sequences as a CONVENTIONAL INTERFACE ---
(define (my-filter pred seq)
  (cond ((null? seq) '())
        ((pred (car seq)) (cons (car seq) (my-filter pred (cdr seq))))
        (else (my-filter pred (cdr seq)))))
(define (accumulate op initial seq)
  (if (null? seq) initial (op (car seq) (accumulate op initial (cdr seq)))))
(define (enumerate-interval low high)
  (if (> low high) '() (cons low (enumerate-interval (+ low 1) high))))

(define (square x) (* x x))
(define (odd-int? n) (= 1 (remainder n 2)))

(show (map square '(1 2 3 4 5)))
(show (my-filter odd-int? '(1 2 3 4 5)))
(show (accumulate + 0 '(1 2 3 4 5)))
(show (accumulate * 1 '(1 2 3 4 5)))
(show (enumerate-interval 2 7))

;; the section's point: one pipeline, assembled from those four pieces
(define (sum-odd-squares seq) (accumulate + 0 (map square (my-filter odd-int? seq))))
(show (sum-odd-squares '(1 2 3 4 5 6 7)))

;; --- NESTED mappings: pairs (i,j) with i>j from 1..n, whose sum is prime ---
(define (flatmap proc seq) (accumulate my-append '() (map proc seq)))
(define (divides? a b) (= 0 (remainder b a)))
(define (find-div n t) (cond ((> (* t t) n) n) ((divides? t n) t) (else (find-div n (+ t 1)))))
(define (prime? n) (and (> n 1) (= n (find-div n 2))))

(define (unique-pairs n)
  (flatmap (lambda (i) (map (lambda (j) (list i j)) (enumerate-interval 1 (- i 1))))
           (enumerate-interval 1 n)))
(define (prime-sum-pairs n)
  (map (lambda (p) (list (car p) (cadr p) (+ (car p) (cadr p))))
       (my-filter (lambda (p) (prime? (+ (car p) (cadr p)))) (unique-pairs n))))

(show (unique-pairs 4))
(show (prime-sum-pairs 6))

;; permutations, the other nested mapping
(define (remove-item x seq) (my-filter (lambda (y) (not (= y x))) seq))
(define (permutations s)
  (if (null? s) (list '())
      (flatmap (lambda (x) (map (lambda (p) (cons x p)) (permutations (remove-item x s)))) s)))
(show (permutations '(1 2 3)))
(show (my-length (permutations '(1 2 3 4))))
