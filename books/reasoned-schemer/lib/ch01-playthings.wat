;; The Reasoned Schemer, chapter 1 (Playthings): the chapter's one relation. Our own code.
;; Needs lib/ch10-under-the-hood.wat (the engine and its macros).

;; teacupo: t is tea or cup.
(rs/defrel (rs/teacupo t)
  (rs/disj2 (rs/== (rs/q 'tea) t) (rs/== (rs/q 'cup) t)))
