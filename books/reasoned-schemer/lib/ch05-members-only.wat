;; The Reasoned Schemer, chapter 5 (Members Only): mem and rember as relations. Our own code.
;; Needs lib/ch10-under-the-hood.wat and lib/ch02-old-toys.wat. oracle/rels.clj holds
;; identical Clojure twins, for the differential check.

;; memo: out is the suffix of l that starts with x.
(rs/defrel (rs/memo x l out)
  (rs/conde ((rs/caro l x) (rs/== l out))
            ((rs/fresh (d) (rs/cdro l d) (rs/memo x d out)))))

;; rembero: out is l with one x removed, or with none removed (the third line may pass
;; any element through, x included).
(rs/defrel (rs/rembero x l out)
  (rs/conde ((rs/nullo l) (rs/== (rs/nil) out))
            ((rs/conso x out l))
            ((rs/fresh (a d res)
               (rs/conso a d l)
               (rs/conso a res out)
               (rs/rembero x d res)))))

;; surpriseo: removing s from (a b c) leaves (a b c).
(rs/defrel (rs/surpriseo s)
  (rs/rembero s (rs/q '(a b c)) (rs/q '(a b c))))
