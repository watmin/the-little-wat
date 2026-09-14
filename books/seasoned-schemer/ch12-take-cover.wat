;; The Seasoned Schemer, chapter 12 (Take Cover): letrec's job, hiding a recursive helper
;; that closes over unchanging arguments, done with Y. The definitions live in
;; lib/ch12-take-cover.wat; this program checks them. Our own code and examples.
;;
;; Run: wat books/seasoned-schemer/ch12-take-cover.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch02-do-it-again.wat")
(:wat::load-file! "../little-schemer/lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "../little-schemer/lib/ch06-shadows.wat")
(:wat::load-file! "../little-schemer/lib/ch07-friends-and-relations.wat")
(:wat::load-file! "../little-schemer/lib/ch08-lambda-the-ultimate.wat")
(:wat::load-file! "../little-schemer/lib/ch09-and-again.wat")
(:wat::load-file! "lib/ch12-take-cover.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; the top-level helper and the Y-hidden helper agree
    (wat.test/assert-eq (ss/multirember-top 'plum '(plum pear plum fig)) '(pear fig))
    (wat.test/assert-eq (ss/multirember 'plum '(plum pear plum fig)) '(pear fig))
    (wat.test/assert-eq (ss/multirember 'kiwi '()) '())

    (wat.test/assert-eq (ss/member? 'fig '(pear fig)) true)
    (wat.test/assert-eq (ss/member? 'kiwi '(pear fig)) false)

    (wat.test/assert-eq (ss/union '(pear plum) '(plum fig)) '(pear plum fig))

    ;; curried helpers: Y instantiated with a function type as its result
    (wat.test/assert-eq (ss/two-in-a-row? '(pear plum plum)) true)
    (wat.test/assert-eq (ss/two-in-a-row? '(pear plum pear)) false)
    (wat.test/assert-eq (ss/sum-of-prefixes [1 2 3]) [1 3 6])
    (wat.test/assert-eq (ss/sum-of-prefixes [5 0 2]) [5 5 7])

    (wat.kernel/println "seasoned-schemer ch12 take-cover: ok")))
