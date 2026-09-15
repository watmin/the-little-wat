;; The Reasoned Schemer, chapter 3 (Seeing Old Friends in New Ways): listo, lolo, loso,
;; membero and proper-membero. Our own code and examples. Every expected value here is the
;; output of oracle/ch03.clj, the same queries in a Clojure transliteration of the book's
;; engine, so the answer ORDER (set by interleaving) is checked, not only the answers.
;;
;; Run: wat books/reasoned-schemer/ch03-old-friends.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")
(:wat::load-file! "lib/ch03-old-friends.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; listo: a fresh element is fine; a fresh tail enumerates every length
    (wat.test/assert-eq (rs/run* x (rs/listo (rs/list [(rs/q 'a) (rs/q 'b) x (rs/q 'd)]))) '(_0))
    (wat.test/assert-eq (rs/run 1 x (rs/listo (rs/list* [(rs/q 'a) (rs/q 'b) (rs/q 'c)] x))) '(()))
    (wat.test/assert-eq (rs/run 5 x (rs/listo (rs/list* [(rs/q 'a) (rs/q 'b) (rs/q 'c)] x)))
                        '(() (_0) (_0 _1) (_0 _1 _2) (_0 _1 _2 _3)))

    ;; lolo: the two ways to grow interleave
    (wat.test/assert-eq (rs/run 1 l (rs/lolo l)) '(()))
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y)
                                     (rs/lolo (rs/list [(rs/q '(a b)) (rs/list [x (rs/q 'c)]) (rs/list [(rs/q 'd) y])]))))
                        '(_0))
    (wat.test/assert-eq (rs/run 1 x (rs/lolo (rs/list* [(rs/q '(a b)) (rs/q '(c d))] x))) '(()))
    (wat.test/assert-eq (rs/run 5 x (rs/lolo (rs/list* [(rs/q '(a b)) (rs/q '(c d))] x)))
                        '(() (()) ((_0)) (() ()) ((_0 _1))))
    (wat.test/assert-eq (rs/run 5 x (rs/lolo x)) '(() (()) ((_0)) (() ()) ((_0 _1))))

    ;; loso
    (wat.test/assert-eq (rs/run 1 z (rs/loso (rs/list* [(rs/q '(g))] z))) '(()))
    (wat.test/assert-eq (rs/run 5 z (rs/loso (rs/list* [(rs/q '(g))] z)))
                        '(() ((_0)) ((_0) (_1)) ((_0) (_1) (_2)) ((_0) (_1) (_2) (_3))))
    (wat.test/assert-eq (rs/run 4 r (rs/fresh (w x y z)
                                      (rs/loso (rs/list* [(rs/q '(g)) (rs/cons (rs/q 'e) w) (rs/cons x y)] z))
                                      (rs/== (rs/list [w (rs/cons x y) z]) r)))
                        '((() (_0) ()) (() (_0) ((_1))) (() (_0) ((_1) (_2))) (() (_0) ((_1) (_2) (_3)))))

    ;; membero, run every way
    (wat.test/assert-eq (rs/run* q (rs/membero (rs/q 'olive) (rs/q '(virgin olive oil)))) '(_0))
    (wat.test/assert-eq (rs/run 1 y (rs/membero y (rs/q '(hummus with pita)))) '(hummus))
    (wat.test/assert-eq (rs/run* y (rs/membero y (rs/q '(hummus with pita)))) '(hummus with pita))
    (wat.test/assert-eq (rs/run* y (rs/membero (rs/q 'e) (rs/list [(rs/q 'pasta) y (rs/q 'fagioli)]))) '(e))
    (wat.test/assert-eq (rs/run* x (rs/membero (rs/q 'e) (rs/list [(rs/q 'pasta) (rs/q 'e) x (rs/q 'fagioli)])))
                        '(_0 e))
    (wat.test/assert-eq (rs/run* (x y) (rs/membero (rs/q 'e) (rs/list [(rs/q 'pasta) x (rs/q 'fagioli) y])))
                        '((e _0) (_0 e)))
    (wat.test/assert-eq (rs/run* q (rs/fresh (x y)
                                     (rs/== (rs/list [(rs/q 'pasta) x (rs/q 'fagioli) y]) q)
                                     (rs/membero (rs/q 'e) q)))
                        '((pasta e fagioli _0) (pasta _0 fagioli e)))
    ;; lists that contain tofu: the tail stays open
    (wat.test/assert-eq (rs/run 1 l (rs/membero (rs/q 'tofu) l)) '((tofu & _0)))
    (wat.test/assert-eq (rs/run 5 l (rs/membero (rs/q 'tofu) l))
                        '((tofu & _0) (_0 tofu & _1) (_0 _1 tofu & _2) (_0 _1 _2 tofu & _3) (_0 _1 _2 _3 tofu & _4)))
    ;; proper lists that contain tofu: the two conde lines interleave
    (wat.test/assert-eq (rs/run 5 l (rs/proper-membero (rs/q 'tofu) l))
                        '((tofu) (tofu _0) (tofu _0 _1) (_0 tofu) (tofu _0 _1 _2)))

    (wat.kernel/println "reasoned-schemer ch03 old-friends: ok")))
