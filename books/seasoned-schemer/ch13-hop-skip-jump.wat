;; The Seasoned Schemer, chapter 13 (Hop, Skip, and Jump): letcc's escapes, ported to
;; Result/try. The definitions live in lib/ch13-hop-skip-jump.wat; this program checks them.
;; Our own code and examples, not the book's text.
;;
;; Run: wat books/seasoned-schemer/ch13-hop-skip-jump.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch02-do-it-again.wat")
(:wat::load-file! "../little-schemer/lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "../little-schemer/lib/ch07-friends-and-relations.wat")
(:wat::load-file! "lib/ch13-hop-skip-jump.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; intersectall: the normal answer, and the hop when an empty set appears anywhere
    (wat.test/assert-eq (ss/intersectall '((pear plum fig) (plum fig kiwi) (fig plum))) '(plum fig))
    (wat.test/assert-eq (ss/intersectall '((pear plum) () (plum fig))) '())
    (wat.test/assert-eq (ss/intersectall '((pear plum) (plum fig) ())) '())
    (wat.test/assert-eq (ss/intersectall '()) '())

    ;; rember-beyond-first
    (wat.test/assert-eq (ss/rember-beyond-first 'plum '(pear fig plum kiwi plum)) '(pear fig))
    (wat.test/assert-eq (ss/rember-beyond-first 'lime '(pear fig)) '(pear fig))

    ;; rember-upto-last: the skip, which abandons everything consed before the last plum
    (wat.test/assert-eq (ss/rember-upto-last 'plum '(pear plum fig plum kiwi lime)) '(kiwi lime))
    (wat.test/assert-eq (ss/rember-upto-last 'plum '(pear fig)) '(pear fig))
    (wat.test/assert-eq (ss/rember-upto-last 'plum '(pear fig plum)) '())

    (wat.kernel/println "seasoned-schemer ch13 hop-skip-jump: ok")))
