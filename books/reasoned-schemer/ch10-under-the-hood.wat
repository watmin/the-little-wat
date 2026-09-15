;; The Reasoned Schemer, chapter 10 (Under the Hood): the engine itself, checked piece by
;; piece. The definitions live in lib/ch10-under-the-hood.wat. Our own code and examples.
;;
;; Run: wat books/reasoned-schemer/ch10-under-the-hood.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")

;; appendo, as the book writes it in ch 4, to drive the engine forwards and backwards.
(rs/defrel (rsx/appendo l t out)
  (rs/conde ((rs/== l (rs/nil)) (rs/== t out))
            ((rs/fresh (a d res)
               (rs/== (rs/cons a d) l)
               (rs/== (rs/cons a res) out)
               (rsx/appendo d t res)))))

;; nevero never succeeds and never fails; alwayso succeeds forever.
(rs/defrel (rsx/nevero) (rsx/nevero))
(rs/defrel (rsx/alwayso) (rs/conde ((rs/succeed)) ((rsx/alwayso))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; unify, walk, reify
    (wat.test/assert-eq (rs/run* q (rs/fail)) '())
    (wat.test/assert-eq (rs/run* q (rs/succeed)) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/q 'pea))) '(pea))
    (wat.test/assert-eq (rs/run* q (rs/== (rs/q '(a b)) (rs/list [(rs/q 'a) q]))) '(b))
    ;; the occurs check: q cannot equal a list containing q
    (wat.test/assert-eq (rs/run* q (rs/== q (rs/list [q]))) '())
    ;; fresh variables reify in order of appearance
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y) (rs/== q (rs/list [y x y])))) '((_0 _1 _0)))
    ;; an improper tail
    (wat.test/assert-eq (rs/run* q (rs/fresh (d) (rs/== q (rs/list* [(rs/q 'a) (rs/q 'b)] d))))
                        '((a b & _0)))
    ;; conde's answers, in the book's order
    (wat.test/assert-eq (rs/run* q (rs/conde ((rs/== q (rs/q 'olive)))
                                             ((rs/fail))
                                             ((rs/== q (rs/q 'oil)))))
                        '(olive oil))
    ;; appendo forwards, then backwards: every way to split (a b c)
    (wat.test/assert-eq (rs/run* q (rsx/appendo (rs/q '(a b)) (rs/q '(c d)) q)) '((a b c d)))
    (wat.test/assert-eq (rs/run* (x y) (rsx/appendo x y (rs/q '(a b c))))
                        '((() (a b c)) ((a) (b c)) ((a b) (c)) ((a b c) ())))
    ;; interleaving: a branch that never answers does not starve its sibling
    (wat.test/assert-eq (rs/run 1 q (rs/conde ((rsx/nevero)) ((rs/== q (rs/q 'tea))))) '(tea))
    ;; an infinite stream, taken finitely
    (wat.test/assert-eq (rs/run 3 q (rsx/alwayso) (rs/== q (rs/q 'onion))) '(onion onion onion))
    ;; the functions under the macros, called directly
    (wat.test/assert-eq (rs/run-goal -1 (wat.core/fn [q :- :rs::Term] :- :rs::Goal
                                          (rs/disj2 (rs/== q (rs/q 'a)) (rs/== q (rs/q 'b)))))
                        '(a b))

    (wat.kernel/println "reasoned-schemer ch10 under-the-hood: ok")))
