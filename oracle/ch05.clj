;; oracle/ch05.clj: the queries of books/reasoned-schemer/ch05-members-only.wat, in the
;; oracle. Its output is the wat chapter's expected values.
;; Run: clojure -M oracle/ch05.clj
(load-file "oracle/mk.clj")
(in-ns 'mk)
(load-file "oracle/rels.clj")

(println "== ch05")
(show "memo-none" (run* q (memo 'fig (quo '(pea)) q)))
(show "memo-fig" (run* out (memo 'fig (quo '(fig)) out)))
(show "memo-fig-pea" (run* out (memo 'fig (quo '(fig pea)) out)))
(show "memo-r" (run* r (memo r (quo '(roll okra fig beet fig pea)) (quo '(fig beet fig pea)))))
(show "memo-xy" (run* (x y) (memo 'fig (quo '(fig pea)) (lst x y))))
(show "memo-twice" (run* x (memo 'fig (quo '(fig fig pea)) x)))
(show "memo-suffix-3" (run 3 x (memo 'fig (lst* '[a] x) (quo '(fig fig pea)))))
(show "memo-open-5" (run 5 x (fresh (y) (memo 'fig (lst* '[fig d fig e] y) x))))
(show "rembero-pea" (run* out (rembero 'pea (quo '(pea)) out)))
(show "rembero-pea-pea" (run* out (rembero 'pea (quo '(pea pea)) out)))
(show "rembero-y" (run* out (fresh (y z) (rembero y (lst 'a 'b y 'd z 'e) out))))
(show "rembero-yz" (run* (y z) (rembero y (lst y 'd z 'e) (lst y 'd 'e))))
(show "rembero-4" (run 4 (y z w out) (rembero y (lst* [z] w) out)))
(show "surpriseo-d" (run* r (== 'd r) (surpriseo r)))
(show "surpriseo" (run* r (surpriseo r)))
(show "surpriseo-b" (run* r (surpriseo r) (== 'b r)))
