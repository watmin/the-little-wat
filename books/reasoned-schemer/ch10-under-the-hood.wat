;; The Reasoned Schemer, chapter 10 (Under the Hood): the engine itself, checked piece by
;; piece. The definitions live in lib/ch10-under-the-hood.wat. Our own code and examples.
;;
;; Run: wat books/reasoned-schemer/ch10-under-the-hood.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")

;; appendo, as the book writes it in ch 4, to drive the engine forwards and backwards.
(wat.core/defn rsx/appendo [l :- :rs::Term t :- :rs::Term out :- :rs::Term] :- :rs::Goal
  (rs/delay
    (wat.core/fn [] :- :rs::Goal
      (rs/conde
        [[(rs/== l (rs/nil)) (rs/== t out)]
         [(rs/fresh3 (:wat::core::fn [a <- :rs::Term d <- :rs::Term res <- :rs::Term] -> :rs::Goal
                       (rs/conj [(rs/== (rs/cons a d) l)
                                 (rs/== (rs/cons a res) out)
                                 (rsx/appendo d t res)])))]]))))

;; nevero: a relation that never succeeds and never fails.
(wat.core/defn rsx/nevero [] :- :rs::Goal
  (rs/delay (wat.core/fn [] :- :rs::Goal (rsx/nevero))))

;; alwayso: succeeds forever.
(wat.core/defn rsx/alwayso [] :- :rs::Goal
  (rs/delay (wat.core/fn [] :- :rs::Goal
              (rs/conde [[(rs/succeed)] [(rsx/alwayso)]]))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; walk, unify, occurs check
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal (rs/fail))) '())
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal (rs/succeed))) '(_0))
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal (rs/== q (rs/q 'pea)))) '(pea))
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                   (rs/== (rs/q '(a b)) (rs/list [(rs/q 'a) q]))))
                        '(b))
    ;; occurs check: q cannot equal a list containing q
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal (rs/== q (rs/list [q]))))
                        '())
    ;; fresh variables reify in order of appearance
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                   (rs/fresh2 (:wat::core::fn [x <- :rs::Term y <- :rs::Term] -> :rs::Goal
                                                (rs/== q (rs/list [y x y]))))))
                        '((_0 _1 _0)))
    ;; an improper tail
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                   (rs/fresh (:wat::core::fn [d <- :rs::Term] -> :rs::Goal
                                               (rs/== q (rs/list* [(rs/q 'a) (rs/q 'b)] d))))))
                        '((a b & _0)))
    ;; conde's answers, in the book's order
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                   (rs/conde [[(rs/== q (rs/q 'olive))]
                                              [(rs/fail)]
                                              [(rs/== q (rs/q 'oil))]])))
                        '(olive oil))
    ;; appendo forwards
    (wat.test/assert-eq (rs/run* (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                   (rsx/appendo (rs/q '(a b)) (rs/q '(c d)) q)))
                        '((a b c d)))
    ;; appendo backwards: every way to split (a b c)
    (wat.test/assert-eq (rs/run2 -1 (:wat::core::fn [x <- :rs::Term y <- :rs::Term] -> :rs::Goal
                                      (rsx/appendo x y (rs/q '(a b c)))))
                        '((() (a b c)) ((a) (b c)) ((a b) (c)) ((a b c) ())))
    ;; interleaving: a branch that never answers does not starve its sibling
    (wat.test/assert-eq (rs/run 1 (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                    (rs/conde [[(rsx/nevero)] [(rs/== q (rs/q 'tea))]])))
                        '(tea))
    ;; an infinite stream, taken finitely
    (wat.test/assert-eq (rs/run 3 (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                    (rs/conj [(rsx/alwayso) (rs/== q (rs/q 'onion))])))
                        '(onion onion onion))

    (wat.kernel/println "reasoned-schemer ch10 under-the-hood: ok")))
