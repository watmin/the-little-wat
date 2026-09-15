;; The Reasoned Schemer, chapter 9 (Thin Ice): relations built on conda and condu, which are
;; in lib/ch10-under-the-hood.wat with ifte and once. Our own code. oracle/rels.clj holds
;; identical Clojure twins.

;; not-pastao: fails when x is pasta, succeeds otherwise, even when x is fresh.
(rs/defrel (rs/not-pastao x)
  (rs/conda ((rs/== (rs/q 'pasta) x) (rs/fail))
            ((rs/succeed))))

;; onceo: at most g's first answer. It takes a goal rather than a term, so it is a plain
;; defn, not a defrel (whose parameters are all terms).
(wat.core/defn rs/onceo [g :- :rs::Goal] :- :rs::Goal
  (rs/condu (g (rs/succeed))
            ((rs/fail))))
