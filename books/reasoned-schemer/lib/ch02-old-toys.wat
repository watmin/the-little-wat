;; The Reasoned Schemer, chapter 2 (Teaching Old Toys New Tricks): car, cdr, cons, null? and
;; pair? as relations. Our own code. Needs lib/ch10-under-the-hood.wat.

;; caro: a is the car of p.
(rs/defrel (rs/caro p a)
  (rs/fresh (d) (rs/== (rs/cons a d) p)))

;; cdro: d is the cdr of p.
(rs/defrel (rs/cdro p d)
  (rs/fresh (a) (rs/== (rs/cons a d) p)))

;; conso: p is (a . d).
(rs/defrel (rs/conso a d p)
  (rs/== (rs/cons a d) p))

;; nullo: x is ().
(rs/defrel (rs/nullo x)
  (rs/== (rs/nil) x))

;; pairo: p is a pair.
(rs/defrel (rs/pairo p)
  (rs/fresh (a d) (rs/conso a d p)))

;; singletono: l is a list of one element.
(rs/defrel (rs/singletono l)
  (rs/fresh (a) (rs/== (rs/list [a]) l)))
