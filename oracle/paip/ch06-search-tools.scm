;; oracle/paip/ch06-search-tools.scm: our own Scheme on the topic of PAIP chapter 6, building
;; software TOOLS -- one search procedure parameterised by how the frontier is combined, so that
;; depth-first, breadth-first, best-first and beam search are the same program with different
;; arguments. Our code and our examples; Norvig's own code is not read or copied.
;;
;; The chapter's claim is that the four searches differ in ONE function, and the tests below are
;; built to show that rather than assert it: the same graph, the same goal, four combiners, four
;; different orders of exploration. The graph search adds a VISITED set, which is what turns an
;; infinite search over a cyclic graph into a terminating one.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a search returns the goal found, or 'fail, and counts how many states it expanded
(define expanded 0)

(define (tree-search states goal? successors combiner)
  (cond ((null? states) 'fail)
        ((goal? (car states)) (car states))
        (else
         (set! expanded (+ expanded 1))
         (tree-search (combiner (successors (car states)) (cdr states)) goal? successors combiner))))

(define (prepend new old) (append new old))          ; depth first
(define (append-at-end new old) (append old new))    ; breadth first

;; the number line: from n you can reach 2n and n+1
(define (binary-successors n) (list (* 2 n) (+ n 1)))
(define (finite-successors n) (if (> n 20) '() (list (* 2 n) (+ n 1))))

(define (is? target) (lambda (x) (= x target)))

(define (run-search start goal combiner successors)
  (set! expanded 0)
  (let ((r (tree-search (list start) (is? goal) successors combiner)))
    (list r expanded)))

;; depth-first dives: from 1 it goes 2, 4, 8, 16 before ever trying 3
(show (car (run-search 1 8 prepend finite-successors)))
(show (car (run-search 1 12 append-at-end finite-successors)))
;; the SAME program, two combiners, two very different amounts of work
(show (cadr (run-search 1 12 prepend finite-successors)))
(show (cadr (run-search 1 12 append-at-end finite-successors)))
(show (< (cadr (run-search 1 12 prepend finite-successors))
         (cadr (run-search 1 12 append-at-end finite-successors))))

;; --- best-first: sort the frontier by how far the state is from the goal ---
(define (sorter cost-fn)
  (lambda (new old) (sort (append new old) (lambda (a b) (< (cost-fn a) (cost-fn b))))))
(define (diff-from target) (lambda (x) (abs (- x target))))

(show (car (run-search 1 12 (sorter (diff-from 12)) finite-successors)))
(show (cadr (run-search 1 12 (sorter (diff-from 12)) finite-successors)))
;; best-first expands fewer states than breadth-first on this graph
(show (< (cadr (run-search 1 12 (sorter (diff-from 12)) finite-successors))
         (cadr (run-search 1 12 append-at-end finite-successors))))

;; --- beam search: best-first, but the frontier is truncated to the best `width` ---
(define (beam cost-fn width)
  (lambda (new old)
    (let ((all (sort (append new old) (lambda (a b) (< (cost-fn a) (cost-fn b))))))
      (if (> (length all) width) (list-head all width) all))))
(define (list-head l n) (if (or (= n 0) (null? l)) '() (cons (car l) (list-head (cdr l) (- n 1)))))

(show (car (run-search 1 12 (beam (diff-from 12) 2) finite-successors)))
(show (cadr (run-search 1 12 (beam (diff-from 12) 2) finite-successors)))
;; a beam too narrow can MISS a reachable goal, which is the price of the truncation
(show (car (run-search 1 19 (beam (diff-from 19) 1) finite-successors)))

;; --- graph search: a visited set makes a cyclic graph terminate ---
(define (graph-search states goal? successors combiner visited)
  (cond ((null? states) 'fail)
        ((goal? (car states)) (car states))
        ((member (car states) visited)
         (graph-search (cdr states) goal? successors combiner visited))
        (else
         (set! expanded (+ expanded 1))
         (graph-search (combiner (successors (car states)) (cdr states))
                       goal? successors combiner (cons (car states) visited)))))

;; a graph with a cycle: 1 -> 2 -> 3 -> 1, and 3 -> 4
(define (cyclic n)
  (cond ((= n 1) '(2)) ((= n 2) '(3)) ((= n 3) '(1 4)) (else '())))

(set! expanded 0)
(show (graph-search '(1) (is? 4) cyclic prepend '()))
(show expanded)
(set! expanded 0)
(show (graph-search '(1) (is? 99) cyclic prepend '()))
(show expanded)
