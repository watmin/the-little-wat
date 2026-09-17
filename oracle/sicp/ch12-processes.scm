;; oracle/sicp/ch12-processes.scm: our own Scheme on the topic of SICP §1.2, the processes that
;; procedures generate: linear recursion against linear iteration, tree recursion, orders of
;; growth, fast exponentiation, Euclid's gcd, and primality. Our code and our examples.
;;
;; The section's real claim is that two procedures computing the same function can generate
;; different PROCESSES -- one accumulating deferred operations, one not -- and that the difference
;; is a property of the shape, not of the answer. Both versions agree on every value below; where
;; they differ is measured in the wat chapter, which has a stack ceiling to hit.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- linear RECURSION: a chain of deferred multiplications ---
(define (fact-rec n) (if (= n 0) 1 (* n (fact-rec (- n 1)))))

;; --- linear ITERATION: the same function, constant space, state in the arguments ---
(define (fact-iter-inner product counter n)
  (if (> counter n) product (fact-iter-inner (* counter product) (+ counter 1) n)))
(define (fact-iter n) (fact-iter-inner 1 1 n))

(show (fact-rec 10))
(show (fact-iter 10))
(show (= (fact-rec 20) (fact-iter 20)))
(show (fact-iter 20))

;; --- TREE recursion: fib, and why it is expensive ---
(define (fib-tree n) (if (< n 2) n (+ (fib-tree (- n 1)) (fib-tree (- n 2)))))
(define (fib-iter-inner a b count) (if (= count 0) b (fib-iter-inner (+ a b) a (- count 1))))
(define (fib-iter n) (fib-iter-inner 1 0 n))

(show (fib-tree 10))
(show (fib-iter 10))
(show (= (fib-tree 20) (fib-iter 20)))
(show (fib-iter 60))

;; counting the calls fib-tree makes: the tree has 2*fib(n+1)-1 nodes, which is why it is bad
(define (fib-calls n) (if (< n 2) 1 (+ 1 (fib-calls (- n 1)) (fib-calls (- n 2)))))
(show (fib-calls 10))
(show (= (fib-calls 10) (- (* 2 (fib-iter 11)) 1)))

;; --- exponentiation: linear against logarithmic ---
(define (expt-lin b n) (if (= n 0) 1 (* b (expt-lin b (- n 1)))))
(define (even-int? n) (= 0 (remainder n 2)))
(define (fast-expt b n)
  (cond ((= n 0) 1)
        ((even-int? n) (let ((h (fast-expt b (quotient n 2)))) (* h h)))
        (else (* b (fast-expt b (- n 1))))))

(show (expt-lin 2 10))
(show (fast-expt 2 10))
(show (= (expt-lin 3 15) (fast-expt 3 15)))
(show (fast-expt 2 62))

;; --- Euclid's gcd: the number of steps is logarithmic (Lame's theorem) ---
(define (my-gcd a b) (if (= b 0) a (my-gcd b (remainder a b))))
(show (my-gcd 206 40))
(show (my-gcd 1071 462))

;; --- primality by trial division, O(sqrt n) ---
(define (divides? a b) (= 0 (remainder b a)))
(define (find-divisor n test)
  (cond ((> (* test test) n) n)
        ((divides? test n) test)
        (else (find-divisor n (+ test 1)))))
(define (smallest-divisor n) (find-divisor n 2))
(define (prime? n) (and (> n 1) (= n (smallest-divisor n))))

(show (smallest-divisor 199))
(show (smallest-divisor 1999))
(show (smallest-divisor 19999))
(show (prime? 199))
(show (prime? 19999))
(show (filter prime? '(2 3 4 5 6 7 8 9 10 11 12 13)))

;; --- the Fermat test: a^n mod n = a mod n for prime n (Carmichael numbers excepted) ---
(define (expmod base exp m)
  (cond ((= exp 0) 1)
        ((even-int? exp) (remainder (square-int (expmod base (quotient exp 2) m)) m))
        (else (remainder (* base (expmod base (- exp 1) m)) m))))
(define (square-int x) (* x x))
(define (fermat-holds? a n) (= (expmod a n n) (remainder a n)))

(show (fermat-holds? 2 199))
(show (fermat-holds? 3 199))
(show (fermat-holds? 2 19999))
;; 561 is a Carmichael number: composite, yet it passes for every a coprime to it
(show (prime? 561))
(show (fermat-holds? 2 561))
