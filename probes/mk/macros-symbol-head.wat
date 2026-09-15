;; macros-symbol-head.wat: the same macros (lib-macros.wat) called with SYMBOL heads, the
;; Clojure/EDN spelling, including a symbol-named relation. Does a symbol-headed call expand?
;; Expected: pea, ((_0 _1)), ((a b c d)).
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib-macros.wat")

(mk/defrel (mk/appendo l t out)
  (rs/conde [[(rs/== l (rs/nil)) (rs/== t out)]
             [(mk/fresh (a d res)
                (rs/== (rs/cons a d) l)
                (rs/== (rs/cons a res) out)
                (mk/appendo d t res))]]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.test/assert-eq (mk/run* q (rs/== q (rs/q 'pea))) '(pea))
    (wat.test/assert-eq (mk/run* q (mk/fresh (x y) (rs/== q (rs/list [x y])))) '((_0 _1)))
    (wat.test/assert-eq (mk/run* q (mk/appendo (rs/q '(a b)) (rs/q '(c d)) q)) '((a b c d)))
    (wat.kernel/println "macros-symbol-head: ok")))
