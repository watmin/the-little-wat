;; The Reasoned Schemer, chapter 1 (Playthings): goals, run*, fresh variables, conj2, disj2,
;; conde, and a first relation. Our own code and examples. The book's #t and #f are the
;; atoms true and false here.
;;
;; Run: wat books/reasoned-schemer/ch01-playthings.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch01-playthings.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; goals that fail and succeed
    (wat.test/assert-eq (rs/run* q (rs/fail)) '())
    (wat.test/assert-eq (rs/run* q (rs/succeed)) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/== (rs/q 'pea) (rs/q 'pod))) '())
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/q 'pea))) '(pea))
    (wat.test/assert-eq (rs/run* q (rs/== (rs/q 'pea) q)) '(pea))

    ;; fresh variables: unused, fused with q, inside a list
    (wat.test/assert-eq (rs/run* q (rs/fresh (x) (rs/== (rs/q 'pea) q))) '(pea))
    (wat.test/assert-eq (rs/run* q (rs/fresh (x) (rs/== x q))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/fresh (x) (rs/== (rs/list [x]) q))) '((_0)))
    (wat.test/assert-eq (rs/run* q (rs/fresh (x) (rs/== x q) (rs/== (rs/q 'pea) x))) '(pea))
    ;; q is (x y) and y is x, so both positions name the same fresh variable
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y)
                                     (rs/== (rs/list [q y]) (rs/list [(rs/list [x y]) x]))))
                        '((_0 _0)))
    ;; an inner fresh x shadows the query variable x, which stays fresh
    (wat.test/assert-eq (rs/run* x (rs/fresh (x) (rs/== (rs/q 'pea) x))) '(_0))

    ;; conj2 and disj2
    (wat.test/assert-eq (rs/run* q (rs/conj2 (rs/succeed) (rs/== (rs/q 'corn) q))) '(corn))
    (wat.test/assert-eq (rs/run* q (rs/conj2 (rs/fail) (rs/== (rs/q 'corn) q))) '())
    (wat.test/assert-eq (rs/run* q (rs/conj2 (rs/== (rs/q 'olive) q) (rs/== (rs/q 'oil) q))) '())
    (wat.test/assert-eq (rs/run* q (rs/disj2 (rs/== (rs/q 'olive) q) (rs/fail))) '(olive))
    (wat.test/assert-eq (rs/run* q (rs/disj2 (rs/== (rs/q 'olive) q) (rs/== (rs/q 'oil) q))) '(olive oil))
    (wat.test/assert-eq (rs/run* x (rs/disj2 (rs/conj2 (rs/== (rs/q 'olive) x) (rs/fail))
                                             (rs/== (rs/q 'oil) x)))
                        '(oil))
    (wat.test/assert-eq (rs/run* x (rs/disj2 (rs/== (rs/q 'oil) x)
                                             (rs/conj2 (rs/== (rs/q 'olive) x) (rs/succeed))))
                        '(oil olive))
    ;; a succeed among the alternatives answers a fresh x, in its place
    (wat.test/assert-eq (rs/run* x (rs/disj2 (rs/conj2 (rs/== (rs/q 'virgin) x) (rs/fail))
                                             (rs/disj2 (rs/== (rs/q 'olive) x)
                                                       (rs/disj2 (rs/succeed) (rs/== (rs/q 'oil) x)))))
                        '(olive _0 oil))

    ;; several query variables
    (wat.test/assert-eq (rs/run* r (rs/fresh (x) (rs/fresh (y)
                                     (rs/== (rs/q 'split) x) (rs/== (rs/q 'pea) y)
                                     (rs/== (rs/list [x y]) r))))
                        '((split pea)))
    (wat.test/assert-eq (rs/run* (x y) (rs/== (rs/q 'split) x) (rs/== (rs/q 'pea) y)) '((split pea)))

    ;; conde
    (wat.test/assert-eq (rs/run* (x y) (rs/conde ((rs/== (rs/q 'split) x) (rs/== (rs/q 'pea) y))
                                                 ((rs/== (rs/q 'red) x) (rs/== (rs/q 'bean) y))))
                        '((split pea) (red bean)))
    (wat.test/assert-eq (rs/run* x (rs/conde ((rs/== (rs/q 'olive) x) (rs/fail))
                                             ((rs/== (rs/q 'oil) x))))
                        '(oil))
    (wat.test/assert-eq (rs/run* (x y) (rs/conde ((rs/fresh (z) (rs/== (rs/q 'lentil) z)))
                                                 ((rs/== x y))))
                        '((_0 _1) (_0 _0)))

    ;; teacupo, a relation
    (wat.test/assert-eq (rs/run* x (rs/teacupo x)) '(tea cup))
    (wat.test/assert-eq (rs/run* (x y) (rs/teacupo x) (rs/teacupo y))
                        '((tea tea) (tea cup) (cup tea) (cup cup)))
    ;; a relation suspends before it answers, so the line without one answers first
    (wat.test/assert-eq (rs/run* (x y) (rs/conde ((rs/teacupo x) (rs/== (rs/q 'true) y))
                                                 ((rs/== (rs/q 'false) x) (rs/== (rs/q 'true) y))))
                        '((false true) (tea true) (cup true)))
    (wat.test/assert-eq (rs/run* (x y) (rs/conde ((rs/teacupo x) (rs/teacupo x))
                                                 ((rs/== (rs/q 'false) x) (rs/teacupo y))))
                        '((false tea) (false cup) (tea _0) (cup _0)))

    (wat.kernel/println "reasoned-schemer ch01 playthings: ok")))
