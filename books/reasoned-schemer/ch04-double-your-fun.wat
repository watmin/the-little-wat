;; The Reasoned Schemer, chapter 4 (Double Your Fun): appendo, run forwards and backwards,
;; swappendo, and unwrapo. Our own code and examples. Every expected value here is the output
;; of oracle/ch04.clj, the same queries in a Clojure transliteration of the book's engine.
;; In the answers, & always marks an improper tail: the data avoids a & atom.
;;
;; Run: wat books/reasoned-schemer/ch04-double-your-fun.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")
(:wat::load-file! "lib/ch04-double-your-fun.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; forwards, with fresh variables in the first list and in the tail
    (wat.test/assert-eq (rs/run* x (rs/appendo (rs/q '(cake)) (rs/q '(tastes yummy)) x))
                        '((cake tastes yummy)))
    (wat.test/assert-eq (rs/run* x (rs/fresh (y) (rs/appendo (rs/q* '(cake + ice) (rs/list [y]))
                                                             (rs/q '(tastes yummy)) x)))
                        '((cake + ice _0 tastes yummy)))
    (wat.test/assert-eq (rs/run* x (rs/fresh (y) (rs/appendo (rs/q '(cake + ice cream)) y x)))
                        '((cake + ice cream & _0)))
    (wat.test/assert-eq (rs/run* x (rs/fresh (z) (rs/appendo (rs/q '(cake + ice cream)) (rs/q* '(d t) z) x)))
                        '((cake + ice cream d t & _0)))

    ;; an open first list: one answer per length
    (wat.test/assert-eq (rs/run 1 x (rs/fresh (y) (rs/appendo (rs/q* '(cake + ice) y) (rs/q '(d t)) x)))
                        '((cake + ice d t)))
    (wat.test/assert-eq (rs/run 5 x (rs/fresh (y) (rs/appendo (rs/q* '(cake + ice) y) (rs/q '(d t)) x)))
                        '((cake + ice d t) (cake + ice _0 d t) (cake + ice _0 _1 d t)
                          (cake + ice _0 _1 _2 d t) (cake + ice _0 _1 _2 _3 d t)))
    (wat.test/assert-eq (rs/run 5 y (rs/fresh (x) (rs/appendo (rs/q* '(cake + ice) y) (rs/q '(d t)) x)))
                        '(() (_0) (_0 _1) (_0 _1 _2) (_0 _1 _2 _3)))
    ;; the same fresh tail in both lists
    (wat.test/assert-eq (rs/run 5 x (rs/fresh (y) (rs/appendo (rs/q* '(cake + ice) y) (rs/q* '(d t) y) x)))
                        '((cake + ice d t) (cake + ice _0 d t _0) (cake + ice _0 _1 d t _0 _1)
                          (cake + ice _0 _1 _2 d t _0 _1 _2) (cake + ice _0 _1 _2 _3 d t _0 _1 _2 _3)))

    ;; backwards: every way to split a list
    (wat.test/assert-eq (rs/run 6 x (rs/fresh (y) (rs/appendo x y (rs/q '(cake + ice d t)))))
                        '(() (cake) (cake +) (cake + ice) (cake + ice d) (cake + ice d t)))
    (wat.test/assert-eq (rs/run 6 y (rs/fresh (x) (rs/appendo x y (rs/q '(cake + ice d t)))))
                        '((cake + ice d t) (+ ice d t) (ice d t) (d t) (t) ()))
    (wat.test/assert-eq (rs/run* (x y) (rs/appendo x y (rs/q '(cake + ice d t))))
                        '((() (cake + ice d t)) ((cake) (+ ice d t)) ((cake +) (ice d t))
                          ((cake + ice) (d t)) ((cake + ice d) (t)) ((cake + ice d t) ())))
    ;; swappendo finds the same six splits, in the same order here
    (wat.test/assert-eq (rs/run* (x y) (rs/swappendo x y (rs/q '(cake + ice d t))))
                        '((() (cake + ice d t)) ((cake) (+ ice d t)) ((cake +) (ice d t))
                          ((cake + ice) (d t)) ((cake + ice d) (t)) ((cake + ice d t) ())))

    ;; unwrapo
    (wat.test/assert-eq (rs/run* x (rs/unwrapo (rs/q '(((pizza)))) x)) '((((pizza))) ((pizza)) (pizza) pizza))
    (wat.test/assert-eq (rs/run 1 x (rs/unwrapo x (rs/q 'pizza))) '(pizza))
    (wat.test/assert-eq (rs/run 1 x (rs/unwrapo (rs/list [(rs/list [x])]) (rs/q 'pizza))) '(pizza))
    (wat.test/assert-eq (rs/run 5 x (rs/unwrapo x (rs/q 'pizza)))
                        '(pizza (pizza & _0) ((pizza & _0) & _1) (((pizza & _0) & _1) & _2)
                          ((((pizza & _0) & _1) & _2) & _3)))
    (wat.test/assert-eq (rs/run 5 x (rs/unwrapo x (rs/q '((pizza)))))
                        '(((pizza)) (((pizza)) & _0) ((((pizza)) & _0) & _1) (((((pizza)) & _0) & _1) & _2)
                          ((((((pizza)) & _0) & _1) & _2) & _3)))
    (wat.test/assert-eq (rs/run 5 x (rs/unwrapo (rs/list [(rs/list [x])]) (rs/q 'pizza)))
                        '(pizza (pizza & _0) ((pizza & _0) & _1) (((pizza & _0) & _1) & _2)
                          ((((pizza & _0) & _1) & _2) & _3)))

    (wat.kernel/println "reasoned-schemer ch04 double-your-fun: ok")))
