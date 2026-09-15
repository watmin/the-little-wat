;; The Reasoned Schemer, chapter 3 (Seeing Old Friends in New Ways): lat?, member? and friends
;; as relations. Our own code. Needs lib/ch10-under-the-hood.wat and lib/ch02-old-toys.wat.
;; oracle/rels.clj holds identical Clojure twins of these, for the differential check.

;; listo: l is a proper list.
(rs/defrel (rs/listo l)
  (rs/conde ((rs/nullo l))
            ((rs/fresh (d) (rs/cdro l d) (rs/listo d)))))

;; lolo: l is a list of lists.
(rs/defrel (rs/lolo l)
  (rs/conde ((rs/nullo l))
            ((rs/fresh (a) (rs/caro l a) (rs/listo a))
             (rs/fresh (d) (rs/cdro l d) (rs/lolo d)))))

;; loso: l is a list of singletons.
(rs/defrel (rs/loso l)
  (rs/conde ((rs/nullo l))
            ((rs/fresh (a) (rs/caro l a) (rs/singletono a))
             (rs/fresh (d) (rs/cdro l d) (rs/loso d)))))

;; membero: x is an element of l.
(rs/defrel (rs/membero x l)
  (rs/conde ((rs/caro l x))
            ((rs/fresh (d) (rs/cdro l d) (rs/membero x d)))))

;; proper-membero: x is an element of l, and l is a proper list.
(rs/defrel (rs/proper-membero x l)
  (rs/conde ((rs/caro l x) (rs/fresh (d) (rs/cdro l d) (rs/listo d)))
            ((rs/fresh (d) (rs/cdro l d) (rs/proper-membero x d)))))
