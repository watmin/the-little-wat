;; The Reasoned Schemer, chapter 6 (The Fun Never Ends...): alwayso, nevero, and interleaving
;; that still finds answers beside branches that never finish. Our own code and examples.
;; Every expected value here is the output of oracle/ch06.clj, the same queries in a Clojure
;; transliteration of the book's engine.
;;
;; Run: wat books/reasoned-schemer/ch06-the-fun-never-ends.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch06-the-fun-never-ends.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; alwayso: as many answers as asked for
    (wat.test/assert-eq (rs/run 1 q (rs/alwayso)) '(_0))
    (wat.test/assert-eq (rs/run 5 q (rs/alwayso)) '(_0 _0 _0 _0 _0))
    (wat.test/assert-eq (rs/run 5 q (rs/== (rs/q 'onion) q) (rs/alwayso)) '(onion onion onion onion onion))
    ;; the garlic line keeps succeeding with the wrong value, and never blocks the onion line
    (wat.test/assert-eq (rs/run 1 q (rs/conde ((rs/== (rs/q 'garlic) q) (rs/alwayso))
                                              ((rs/== (rs/q 'onion) q)))
                                    (rs/== (rs/q 'onion) q))
                        '(onion))
    (wat.test/assert-eq (rs/run 5 q (rs/conde ((rs/== (rs/q 'garlic) q) (rs/alwayso))
                                              ((rs/== (rs/q 'onion) q) (rs/alwayso)))
                                    (rs/== (rs/q 'onion) q))
                        '(onion onion onion onion onion))

    ;; nevero beside answers
    (wat.test/assert-eq (rs/run 1 q (rs/conde ((rs/nevero)) ((rs/== (rs/q 'carrot) q)))) '(carrot))
    (wat.test/assert-eq (rs/run 5 q (rs/conde ((rs/== (rs/q 'spicy) q) (rs/nevero))
                                              ((rs/== (rs/q 'hot) q))
                                              ((rs/== (rs/q 'apple) q) (rs/alwayso))
                                              ((rs/== (rs/q 'cider) q))))
                        '(hot cider apple apple apple))
    (wat.test/assert-eq (rs/run 2 q (rs/conde ((rs/== (rs/q 'tea) q) (rs/nevero))
                                              ((rs/== (rs/q 'cup) q))
                                              ((rs/== (rs/q 'tea) q))))
                        '(cup tea))

    ;; very-recursiveo: answers found among branches that never answer
    (wat.test/assert-eq (wat.core/length (rs/run 1000 q (rs/very-recursiveo))) 1000)

    (wat.kernel/println "reasoned-schemer ch06 the-fun-never-ends: ok")))
