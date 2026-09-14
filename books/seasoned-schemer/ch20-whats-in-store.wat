;; The Seasoned Schemer, chapter 20 (What's in Store?): an interpreter with define, set!,
;; closures holding private mutable state, and escaping letcc. The definitions live in
;; lib/ch20-whats-in-store.wat; this program runs interpreted programs in sequence, sharing
;; one global table, and checks their values. Our own code and example programs.
;;
;; Run: wat books/seasoned-schemer/ch20-whats-in-store.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/cell.wat")
(:wat::load-file! "lib/arena.wat")
(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch02-do-it-again.wat")
(:wat::load-file! "../little-schemer/lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "../little-schemer/lib/ch07-friends-and-relations.wat")
(:wat::load-file! "../little-schemer/lib/ch10-value.wat")
(:wat::load-file! "lib/ch20-whats-in-store.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; constants, quote, primitives, cond
    (wat.test/assert-eq (ssi/value '5) '5)
    (wat.test/assert-eq (ssi/value '(quote (pear plum))) '(pear plum))
    (wat.test/assert-eq (ssi/value '(add1 6)) '7)
    (wat.test/assert-eq (ssi/value '(cond ((null? (quote (a))) 0) (else 1))) '1)

    ;; define and set! on a global
    (wat.test/assert-eq (ssi/value '(define x 3)) 'x)
    (wat.test/assert-eq (ssi/value 'x) '3)
    (wat.test/assert-eq (ssi/value '(set! x 4)) '4)
    (wat.test/assert-eq (ssi/value 'x) '4)

    ;; a closure with PRIVATE mutable state: each call bumps its own n
    (ssi/value '(define make-counter
                  (lambda ()
                    ((lambda (n) (lambda () (set! n (add1 n)) n)) 0))))
    (ssi/value '(define c (make-counter)))
    (ssi/value '(define d (make-counter)))
    (wat.test/assert-eq (ssi/value '(c)) '1)
    (wat.test/assert-eq (ssi/value '(c)) '2)
    (wat.test/assert-eq (ssi/value '(d)) '1)

    ;; recursion through define
    (ssi/value '(define length
                  (lambda (l) (cond ((null? l) 0) (else (add1 (length (cdr l))))))))
    (wat.test/assert-eq (ssi/value '(length (quote (pear plum fig)))) '3)

    ;; letcc: calling k abandons the pending cons
    (wat.test/assert-eq (ssi/value '(letcc k (cons 1 (k 2)))) '2)
    ;; an outer continuation called from inside an inner letcc passes through it
    (wat.test/assert-eq (ssi/value '(letcc outer (cons 1 (letcc inner (outer 5))))) '5)
    ;; a letcc whose continuation is never called answers its body
    (wat.test/assert-eq (ssi/value '(letcc k (cons 1 (quote (2))))) '(1 2))

    (wat.kernel/println "seasoned-schemer ch20 whats-in-store: ok")))
