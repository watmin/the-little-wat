;; The Little Schemer, chapter 7 (Friends and Relations): sets as lats, pairs, relations,
;; functions. The definitions live in lib/ch07-friends-and-relations.wat; this program
;; checks them. Our own code and examples, not the book's text.
;;
;; Run: wat books/little-schemer/ch07-friends-and-relations.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch02-do-it-again.wat")
(:wat::load-file! "lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "lib/ch07-friends-and-relations.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; sets
    (wat.test/assert-eq (ls/set? (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/set? (wat.core/quote (pear plum pear))) false)
    (wat.test/assert-eq (ls/makeset (wat.core/quote (pear plum pear fig plum)))
                        (wat.core/quote (pear plum fig)))
    (wat.test/assert-eq (ls/subset? (wat.core/quote (plum fig)) (wat.core/quote (pear plum fig))) true)
    (wat.test/assert-eq (ls/subset? (wat.core/quote (plum kiwi)) (wat.core/quote (pear plum fig))) false)
    (wat.test/assert-eq (ls/eqset? (wat.core/quote (plum fig)) (wat.core/quote (fig plum))) true)
    (wat.test/assert-eq (ls/intersect? (wat.core/quote (pear kiwi)) (wat.core/quote (kiwi lime))) true)
    (wat.test/assert-eq (ls/intersect? (wat.core/quote (pear)) (wat.core/quote (kiwi lime))) false)
    (wat.test/assert-eq (ls/intersect (wat.core/quote (pear plum fig)) (wat.core/quote (fig kiwi plum)))
                        (wat.core/quote (plum fig)))
    (wat.test/assert-eq (ls/union (wat.core/quote (pear plum)) (wat.core/quote (plum fig)))
                        (wat.core/quote (pear plum fig)))
    (wat.test/assert-eq (ls/difference (wat.core/quote (pear plum fig)) (wat.core/quote (plum)))
                        (wat.core/quote (pear fig)))
    (wat.test/assert-eq (ls/intersectall (wat.core/quote ((pear plum fig) (plum fig kiwi) (fig plum))))
                        (wat.core/quote (plum fig)))

    ;; pairs
    (wat.test/assert-eq (ls/a-pair? (wat.core/quote (pear plum))) true)
    (wat.test/assert-eq (ls/a-pair? (wat.core/quote ((pear) (plum fig)))) true)
    (wat.test/assert-eq (ls/a-pair? (wat.core/quote (pear))) false)
    (wat.test/assert-eq (ls/a-pair? (wat.core/quote (pear plum fig))) false)
    (wat.test/assert-eq (ls/a-pair? (wat.core/quote pear)) false)
    (wat.test/assert-eq (ls/build (wat.core/quote pear) (wat.core/quote plum)) (wat.core/quote (pear plum)))
    (wat.test/assert-eq (ls/revpair (wat.core/quote (pear plum))) (wat.core/quote (plum pear)))

    ;; relations and functions
    (wat.test/assert-eq (ls/fun? (wat.core/quote ((1 pear) (2 plum) (3 fig)))) true)
    (wat.test/assert-eq (ls/fun? (wat.core/quote ((1 pear) (1 plum)))) false)
    (wat.test/assert-eq (ls/revrel (wat.core/quote ((1 pear) (2 plum))))
                        (wat.core/quote ((pear 1) (plum 2))))
    (wat.test/assert-eq (ls/one-to-one? (wat.core/quote ((1 pear) (2 plum)))) true)
    (wat.test/assert-eq (ls/one-to-one? (wat.core/quote ((1 pear) (2 pear)))) false)

    (wat.kernel/println "little-schemer ch07 friends-and-relations: ok")))
