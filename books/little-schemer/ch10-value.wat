;; The Little Schemer, chapter 10 (What Is the Value of All of This?): the interpreter.
;; The definitions live in lib/ch10-value.wat; this program feeds it programs of the
;; book's little language, written as quoted data, and checks their values. Our own code
;; and example programs, not the book's text.
;;
;; The finale: the untyped Y. wat cannot type (lambda (f) (f f)) directly (C-005), but it
;; can host a language that runs it.
;;
;; Run: wat books/little-schemer/ch10-value.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch02-do-it-again.wat")
(:wat::load-file! "lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch07-friends-and-relations.wat")
(:wat::load-file! "lib/ch10-value.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; constants and quote
    (wat.test/assert-eq (lsi/value (wat.core/quote 5)) (wat.core/quote 5))
    (wat.test/assert-eq (lsi/value (wat.core/quote true)) (wat.core/quote true))
    (wat.test/assert-eq (lsi/value (wat.core/quote (quote (pear plum)))) (wat.core/quote (pear plum)))

    ;; primitives
    (wat.test/assert-eq (lsi/value (wat.core/quote (add1 6))) (wat.core/quote 7))
    (wat.test/assert-eq (lsi/value (wat.core/quote (car (quote (pear plum))))) (wat.core/quote pear))
    (wat.test/assert-eq (lsi/value (wat.core/quote (eq? (quote pear) (quote pear)))) (wat.core/quote true))
    (wat.test/assert-eq (lsi/value (wat.core/quote (atom? car))) (wat.core/quote true))
    (wat.test/assert-eq (lsi/value (wat.core/quote (atom? (quote (pear))))) (wat.core/quote false))

    ;; lambda and application
    (wat.test/assert-eq (lsi/value (wat.core/quote ((lambda (x) (add1 x)) 3))) (wat.core/quote 4))
    (wat.test/assert-eq (lsi/value (wat.core/quote ((lambda (x y) (cons x y)) 1 (quote (2)))))
                        (wat.core/quote (1 2)))

    ;; cond, including else
    (wat.test/assert-eq (lsi/value (wat.core/quote (cond ((null? (quote (a))) 0) (else 1))))
                        (wat.core/quote 1))
    (wat.test/assert-eq (lsi/value (wat.core/quote (cond ((eq? (quote pear) (quote pear)) (quote same))
                                                         (else (quote different)))))
                        (wat.core/quote same))

    ;; a closure keeps the table it was made in
    (wat.test/assert-eq (lsi/value (wat.core/quote (((lambda (x) (lambda (y) (cons x y))) (quote pear))
                                                    (quote (plum)))))
                        (wat.core/quote (pear plum)))

    ;; the untyped Y, run inside the interpreter: length with no function naming itself
    (wat.test/assert-eq
      (lsi/value (wat.core/quote
        (((lambda (le)
            ((lambda (f) (f f))
             (lambda (f) (le (lambda (x) ((f f) x))))))
          (lambda (length)
            (lambda (l)
              (cond ((null? l) 0)
                    (else (add1 (length (cdr l))))))))
         (quote (pear plum fig)))))
      (wat.core/quote 3))

    (wat.kernel/println "little-schemer ch10 value: ok")))
