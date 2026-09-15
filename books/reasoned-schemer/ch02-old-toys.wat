;; The Reasoned Schemer, chapter 2 (Teaching Old Toys New Tricks): caro, cdro, conso, nullo,
;; pairo and singletono, run forwards and backwards. Our own code and examples.
;;
;; Run: wat books/reasoned-schemer/ch02-old-toys.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; caro
    (wat.test/assert-eq (rs/run* q (rs/caro (rs/q '(a c o r n)) q)) '(a))
    (wat.test/assert-eq (rs/run* q (rs/caro (rs/q '(a c o r n)) (rs/q 'a))) '(_0))
    (wat.test/assert-eq (rs/run* r (rs/fresh (x y) (rs/caro (rs/list [r y]) x) (rs/== (rs/q 'pear) x)))
                        '(pear))
    (wat.test/assert-eq (rs/run* r (rs/fresh (x y)
                                     (rs/caro (rs/q '(grape raisin pear)) x)
                                     (rs/caro (rs/q '((a) (b) (c))) y)
                                     (rs/== (rs/cons x y) r)))
                        '((grape a)))

    ;; cdro, including one run backwards: what list has cdr (c o r n) and car a?
    (wat.test/assert-eq (rs/run* r (rs/fresh (v)
                                     (rs/cdro (rs/q '(a c o r n)) v)
                                     (rs/fresh (w) (rs/cdro v w) (rs/caro w r))))
                        '(o))
    (wat.test/assert-eq (rs/run* x (rs/cdro (rs/q '(c o r n)) (rs/list [x (rs/q 'r) (rs/q 'n)]))) '(o))
    (wat.test/assert-eq (rs/run* l (rs/fresh (x)
                                     (rs/cdro l (rs/q '(c o r n)))
                                     (rs/caro l x)
                                     (rs/== (rs/q 'a) x)))
                        '((a c o r n)))

    ;; conso, with the unknown in every position
    (wat.test/assert-eq (rs/run* l (rs/conso (rs/q '(a b c)) (rs/q '(d e)) l)) '(((a b c) d e)))
    (wat.test/assert-eq (rs/run* x (rs/conso x (rs/q '(a b c)) (rs/q '(d a b c)))) '(d))
    (wat.test/assert-eq (rs/run* r (rs/fresh (x y z)
                                     (rs/== (rs/list [(rs/q 'e) (rs/q 'a) (rs/q 'd) x]) r)
                                     (rs/conso y (rs/list [(rs/q 'a) z (rs/q 'c)]) r)))
                        '((e a d c)))
    (wat.test/assert-eq (rs/run* x (rs/conso x (rs/list [(rs/q 'a) x (rs/q 'c)])
                                             (rs/list [(rs/q 'd) (rs/q 'a) x (rs/q 'c)])))
                        '(d))
    (wat.test/assert-eq (rs/run* l (rs/fresh (x)
                                     (rs/== (rs/list [(rs/q 'd) (rs/q 'a) x (rs/q 'c)]) l)
                                     (rs/conso x (rs/list [(rs/q 'a) x (rs/q 'c)]) l)))
                        '((d a d c)))

    ;; nullo
    (wat.test/assert-eq (rs/run* q (rs/nullo (rs/q '(grape raisin pear)))) '())
    (wat.test/assert-eq (rs/run* q (rs/nullo (rs/nil))) '(_0))
    (wat.test/assert-eq (rs/run* x (rs/nullo x)) '(()))

    ;; pairo; a fresh pair reifies with an improper tail
    (wat.test/assert-eq (rs/run* q (rs/pairo (rs/cons q q))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/pairo (rs/nil))) '())
    (wat.test/assert-eq (rs/run* q (rs/pairo (rs/q 'pair))) '())
    (wat.test/assert-eq (rs/run* x (rs/pairo x)) '((_0 & _1)))
    (wat.test/assert-eq (rs/run* r (rs/pairo (rs/cons r (rs/nil)))) '(_0))

    ;; singletono
    (wat.test/assert-eq (rs/run* q (rs/singletono (rs/q '(a)))) '(_0))
    (wat.test/assert-eq (rs/run* q (rs/singletono (rs/q '(a b)))) '())
    (wat.test/assert-eq (rs/run* x (rs/singletono x)) '((_0)))

    (wat.kernel/println "reasoned-schemer ch02 old-toys: ok")))
