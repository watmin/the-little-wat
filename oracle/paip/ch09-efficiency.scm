;; oracle/paip/ch09-efficiency.scm: our own Scheme on the topic of PAIP chapter 9, efficiency --
;; MEMOIZATION, and indexing a table so a lookup is not a scan. Our code and our examples;
;; Norvig's own code is not read or copied.
;;
;; The chapter's headline technique is memoizing a function: wrap it so a repeated call is a table
;; lookup rather than a recomputation. The number that makes the case is the CALL COUNT, not the
;; clock, so both versions count their own calls and the counts are what is compared.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- naive fib: the call count is the thing that hurts ---
(define calls 0)
(define (fib n) (set! calls (+ calls 1)) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))

(define (count-fib n) (set! calls 0) (let ((v (fib n))) (list v calls)))

(show (car (count-fib 10)))
(show (cadr (count-fib 10)))
(show (car (count-fib 20)))
(show (cadr (count-fib 20)))
;; the tree has 2*fib(n+1)-1 nodes, which is why it is exponential
(show (= (cadr (count-fib 10)) (- (* 2 (car (count-fib 11))) 1)))

;; --- memoized fib: the table is threaded, so the count is of REAL work only ---
;; (memo-fib n table) -> (value table calls)
(define (memo-fib n table calls)
  (let ((hit (assv n table)))
    (if hit (list (cdr hit) table calls)
        (if (< n 2)
            (list n (cons (cons n n) table) (+ calls 1))
            (let* ((a (memo-fib (- n 1) table (+ calls 1)))
                   (b (memo-fib (- n 2) (cadr a) (caddr a)))
                   (v (+ (car a) (car b))))
              (list v (cons (cons n v) (cadr b)) (caddr b)))))))

(define (mf n) (memo-fib n '() 0))
(show (car (mf 10)))
(show (caddr (mf 10)))
(show (car (mf 20)))
(show (caddr (mf 20)))
(show (car (mf 30)))
(show (caddr (mf 30)))
;; the same answers, and the work is now linear rather than exponential
(show (= (car (mf 20)) (car (count-fib 20))))
(show (< (caddr (mf 20)) (cadr (count-fib 20))))

;; --- indexing: a scan against a table ---
(define entries '((a 1) (b 2) (c 3) (d 4) (e 5) (f 6) (g 7) (h 8)))
(define probes 0)
(define (scan-lookup k es) (cond ((null? es) #f)
                                 (else (set! probes (+ probes 1))
                                       (if (eq? k (car (car es))) (cadr (car es)) (scan-lookup k (cdr es))))))
(define (count-scan k) (set! probes 0) (let ((v (scan-lookup k entries))) (list v probes)))

(show (car (count-scan 'a)))
(show (cadr (count-scan 'a)))
(show (car (count-scan 'h)))
(show (cadr (count-scan 'h)))
;; the last key costs 8 probes and the first costs 1: that gap is what an index removes
(show (- (cadr (count-scan 'h)) (cadr (count-scan 'a))))
(show (car (count-scan 'z)))
