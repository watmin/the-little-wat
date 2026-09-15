;; The Reasoned Schemer, chapter 4 (Double Your Fun): append and friends as relations. Our own
;; code. Needs lib/ch10-under-the-hood.wat and lib/ch02-old-toys.wat. oracle/rels.clj holds
;; identical Clojure twins, for the differential check.

;; appendo: out is l followed by t.
(rs/defrel (rs/appendo l t out)
  (rs/conde ((rs/nullo l) (rs/== t out))
            ((rs/fresh (a d res)
               (rs/conso a d l)
               (rs/conso a res out)
               (rs/appendo d t res)))))

;; swappendo: appendo with its conde lines swapped. The same answers, in another order.
(rs/defrel (rs/swappendo l t out)
  (rs/conde ((rs/fresh (a d res)
               (rs/conso a d l)
               (rs/conso a res out)
               (rs/swappendo d t res)))
            ((rs/nullo l) (rs/== t out))))

;; unwrapo: out is x with any number of its outer single-element wrappings removed.
(rs/defrel (rs/unwrapo x out)
  (rs/conde ((rs/fresh (a) (rs/caro x a) (rs/unwrapo a out)))
            ((rs/== x out))))
