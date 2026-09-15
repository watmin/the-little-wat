;; The Reasoned Schemer, chapter 5 (Members Only): memo and rembero, and the surprise in
;; rembero. Our own code and examples. Every expected value here is the output of
;; oracle/ch05.clj, the same queries in a Clojure transliteration of the book's engine.
;;
;; Run: wat books/reasoned-schemer/ch05-members-only.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib/ch02-old-toys.wat")
(:wat::load-file! "lib/ch05-members-only.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; memo
    (wat.test/assert-eq (rs/run* q (rs/memo (rs/q 'fig) (rs/q '(pea)) q)) '())
    (wat.test/assert-eq (rs/run* out (rs/memo (rs/q 'fig) (rs/q '(fig)) out)) '((fig)))
    (wat.test/assert-eq (rs/run* out (rs/memo (rs/q 'fig) (rs/q '(fig pea)) out)) '((fig pea)))
    (wat.test/assert-eq (rs/run* r (rs/memo r (rs/q '(roll okra fig beet fig pea)) (rs/q '(fig beet fig pea))))
                        '(fig))
    (wat.test/assert-eq (rs/run* (x y) (rs/memo (rs/q 'fig) (rs/q '(fig pea)) (rs/list [x y]))) '((fig pea)))
    ;; every suffix that starts with fig
    (wat.test/assert-eq (rs/run* x (rs/memo (rs/q 'fig) (rs/q '(fig fig pea)) x)) '((fig fig pea) (fig pea)))
    ;; which lists (a . x) have the suffix (fig fig pea)? infinitely many; the first three
    (wat.test/assert-eq (rs/run 3 x (rs/memo (rs/q 'fig) (rs/q* '(a) x) (rs/q '(fig fig pea))))
                        '((fig fig pea) (_0 fig fig pea) (_0 _1 fig fig pea)))
    (wat.test/assert-eq (rs/run 5 x (rs/fresh (y) (rs/memo (rs/q 'fig) (rs/q* '(fig d fig e) y) x)))
                        '((fig d fig e & _0) (fig e & _0) (fig & _0) (fig & _0) (fig & _0)))

    ;; rembero may also remove nothing
    (wat.test/assert-eq (rs/run* out (rs/rembero (rs/q 'pea) (rs/q '(pea)) out)) '(() (pea)))
    (wat.test/assert-eq (rs/run* out (rs/rembero (rs/q 'pea) (rs/q '(pea pea)) out)) '((pea) (pea) (pea pea)))
    (wat.test/assert-eq (rs/run* out (rs/fresh (y z)
                                       (rs/rembero y (rs/list [(rs/q 'a) (rs/q 'b) y (rs/q 'd) z (rs/q 'e)]) out)))
                        '((b a d _0 e) (a b d _0 e) (a b d _0 e) (a b d _0 e) (a b _0 d e) (a b e d _0) (a b _0 d _1 e)))
    (wat.test/assert-eq (rs/run* (y z) (rs/rembero y (rs/list [y (rs/q 'd) z (rs/q 'e)])
                                                     (rs/list [y (rs/q 'd) (rs/q 'e)])))
                        '((d d) (d d) (_0 _0) (e e)))
    (wat.test/assert-eq (rs/run 4 (y z w out) (rs/rembero y (rs/list* [z] w) out))
                        '((_0 _0 _1 _1) (_0 _1 () (_1)) (_0 _1 (_0 & _2) (_1 & _2)) (_0 _1 (_2) (_1 _2))))

    ;; surpriseo: removing s from (a b c) leaves (a b c) — even when s is b
    (wat.test/assert-eq (rs/run* r (rs/== (rs/q 'd) r) (rs/surpriseo r)) '(d))
    (wat.test/assert-eq (rs/run* r (rs/surpriseo r)) '(_0))
    (wat.test/assert-eq (rs/run* r (rs/surpriseo r) (rs/== (rs/q 'b) r)) '(b))

    (wat.kernel/println "reasoned-schemer ch05 members-only: ok")))
