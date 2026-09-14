;; The Seasoned Schemer, chapter 11 (Welcome Back to the Show): accumulators. The
;; definitions live in lib/ch11-welcome-back.wat; this program checks them. Our own code and
;; examples, not the book's text. Quoted data uses the ' shorthand (FINDINGS.md, C-011).
;;
;; Run: wat books/seasoned-schemer/ch11-welcome-back.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch11-welcome-back.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; two-in-a-row?
    (wat.test/assert-eq (ss/two-in-a-row? '(pear plum plum fig)) true)
    (wat.test/assert-eq (ss/two-in-a-row? '(pear plum fig plum)) false)
    (wat.test/assert-eq (ss/two-in-a-row? '()) false)

    ;; sum-of-prefixes
    (wat.test/assert-eq (ss/sum-of-prefixes [1 2 3 4]) [1 3 6 10])
    (wat.test/assert-eq (ss/sum-of-prefixes [5 0 2]) [5 5 7])
    (wat.test/assert-eq (ss/sum-of-prefixes []) [])

    ;; scramble: each n becomes the number n places back, counting itself as 1
    (wat.test/assert-eq (ss/scramble [1 2 1 3]) [1 1 1 2])
    (wat.test/assert-eq (ss/scramble [1 2 3]) [1 1 1])
    (wat.test/assert-eq (ss/scramble [1 2 3 1 4]) [1 1 1 1 2])

    (wat.kernel/println "seasoned-schemer ch11 welcome-back: ok")))
