;; The Reasoned Schemer, chapter 6 (The Fun Never Ends...): goals that succeed forever or
;; never finish. Our own code. Needs lib/ch10-under-the-hood.wat. oracle/rels.clj holds
;; identical Clojure twins, for the differential check.

;; alwayso: succeeds, then succeeds again, forever.
(rs/defrel (rs/alwayso)
  (rs/conde ((rs/succeed)) ((rs/alwayso))))

;; nevero: neither succeeds nor fails.
(rs/defrel (rs/nevero) (rs/nevero))

;; very-recursiveo: an unbounded supply of answers, found among branches that never answer.
(rs/defrel (rs/very-recursiveo)
  (rs/conde ((rs/nevero))
            ((rs/very-recursiveo))
            ((rs/alwayso))
            ((rs/very-recursiveo))
            ((rs/nevero))))
