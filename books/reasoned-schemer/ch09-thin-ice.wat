;; The Reasoned Schemer, chapter 9 (Thin Ice): conda, condu and onceo, the operators that
;; commit to a first answer and so give up running backwards. Our own code and examples. Every
;; expected value here is the output of oracle/ch09.clj, the same queries in a Clojure
;; transliteration of the book's engine. The book's #t and #f are the atoms true and false.
;;
;; Run: wat books/reasoned-schemer/ch09-thin-ice.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch01-playthings.wat")
(:wat::load-file! "lib/ch06-the-fun-never-ends.wat")
(:wat::load-file! "lib/ch09-thin-ice.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; conda: the first line whose question succeeds is the only line tried
    (wat.test/assert-eq (rs/run* q (rs/conda ((rs/== (rs/q 'olive) q) (rs/succeed))
                                             ((rs/== (rs/q 'oil) q) (rs/succeed))))
                        '(olive))
    (wat.test/assert-eq (rs/run* q (rs/conda ((rs/== (rs/q 'virgin) q) (rs/fail))
                                             ((rs/== (rs/q 'olive) q) (rs/succeed))
                                             ((rs/== (rs/q 'oil) q) (rs/succeed))))
                        '())
    ;; the question decides; a failing answer after it does not fall through to the next line
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y)
                                     (rs/== (rs/q 'split) x) (rs/== (rs/q 'pea) y)
                                     (rs/conda ((rs/== (rs/q 'split) x) (rs/== x y))
                                               ((rs/succeed) (rs/succeed)))))
                        '())
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y)
                                     (rs/== (rs/q 'split) x) (rs/== (rs/q 'pea) y)
                                     (rs/conda ((rs/== x y) (rs/== (rs/q 'split) x))
                                               ((rs/succeed) (rs/succeed)))))
                        '(_0))

    ;; not-pastao: with x fresh, "is x pasta?" succeeds, so "not pasta" fails
    (wat.test/assert-eq (rs/run* x (rs/conda ((rs/not-pastao x) (rs/fail))
                                             ((rs/== (rs/q 'spaghetti) x) (rs/succeed))))
                        '(spaghetti))
    (wat.test/assert-eq (rs/run* x (rs/== (rs/q 'spaghetti) x)
                                   (rs/conda ((rs/not-pastao x) (rs/fail))
                                             ((rs/== (rs/q 'spaghetti) x) (rs/succeed))))
                        '())

    ;; the same goal under conde, conda and condu
    (wat.test/assert-eq (rs/run* x (rs/conde ((rs/teacupo x) (rs/succeed)) ((rs/== (rs/q 'false) x) (rs/succeed))))
                        '(false tea cup))
    (wat.test/assert-eq (rs/run* x (rs/conda ((rs/teacupo x) (rs/succeed)) ((rs/== (rs/q 'false) x) (rs/succeed))))
                        '(tea cup))
    (wat.test/assert-eq (rs/run* x (rs/condu ((rs/teacupo x) (rs/succeed)) ((rs/== (rs/q 'false) x) (rs/succeed))))
                        '(tea))
    (wat.test/assert-eq (rs/run* (x y) (rs/conda ((rs/teacupo x) (rs/teacupo y)) ((rs/== (rs/q 'false) x))))
                        '((tea tea) (tea cup) (cup tea) (cup cup)))

    ;; condu takes one answer from alwayso, so run* ends
    (wat.test/assert-eq (rs/run* q (rs/condu ((rs/alwayso) (rs/succeed)) ((rs/fail))) (rs/== (rs/q 'true) q))
                        '(true))

    ;; onceo commits to tea, so a later (== cup x) fails; asked after, it agrees
    (wat.test/assert-eq (rs/run* x (rs/onceo (rs/teacupo x))) '(tea))
    (wat.test/assert-eq (rs/run* x (rs/onceo (rs/teacupo x)) (rs/== (rs/q 'cup) x)) '())
    (wat.test/assert-eq (rs/run* x (rs/== (rs/q 'cup) x) (rs/onceo (rs/teacupo x))) '(cup))

    (wat.kernel/println "reasoned-schemer ch09 thin-ice: ok")))
