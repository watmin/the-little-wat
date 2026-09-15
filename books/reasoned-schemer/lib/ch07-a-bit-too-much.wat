;; The Reasoned Schemer, chapter 7 (A Bit Too Much): binary arithmetic as relations. A number
;; is a little-endian list of bits: () is zero, (1) is one, (0 1) is two, and the last bit is
;; always 1. Our own code, after the book's definitions. Needs lib/ch10-under-the-hood.wat and
;; lib/ch02-old-toys.wat. oracle/rels.clj holds identical Clojure twins.

;; The bit list of a non-negative i64 (a plain function, not a relation).
(wat.core/defn rs/build-num [n :- wat.type/i64] :- :rs::Term
  (wat.core/cond
    ((wat.core/= n 0) (rs/nil))
    ((wat.core/= (:wat::core::mod n 2) 1) (rs/cons (rs/q '1) (rs/build-num (:wat::core::/ (wat.core/- n 1) 2))))
    (:else (rs/cons (rs/q '0) (rs/build-num (:wat::core::/ n 2))))))

(rs/defrel (rs/bit-xoro x y r)
  (rs/conde ((rs/== (rs/q '0) x) (rs/== (rs/q '0) y) (rs/== (rs/q '0) r))
            ((rs/== (rs/q '0) x) (rs/== (rs/q '1) y) (rs/== (rs/q '1) r))
            ((rs/== (rs/q '1) x) (rs/== (rs/q '0) y) (rs/== (rs/q '1) r))
            ((rs/== (rs/q '1) x) (rs/== (rs/q '1) y) (rs/== (rs/q '0) r))))

(rs/defrel (rs/bit-ando x y r)
  (rs/conde ((rs/== (rs/q '0) x) (rs/== (rs/q '0) y) (rs/== (rs/q '0) r))
            ((rs/== (rs/q '1) x) (rs/== (rs/q '0) y) (rs/== (rs/q '0) r))
            ((rs/== (rs/q '0) x) (rs/== (rs/q '1) y) (rs/== (rs/q '0) r))
            ((rs/== (rs/q '1) x) (rs/== (rs/q '1) y) (rs/== (rs/q '1) r))))

;; x + y = r with carry c, one bit each.
(rs/defrel (rs/half-addero x y r c)
  (rs/bit-xoro x y r)
  (rs/bit-ando x y c))

;; b + x + y = r with carry c, one bit each.
(rs/defrel (rs/full-addero b x y r c)
  (rs/fresh (w xy wz)
    (rs/half-addero x y w xy)
    (rs/half-addero w b r wz)
    (rs/bit-xoro xy wz c)))

;; n is positive; n is greater than one.
(rs/defrel (rs/poso n) (rs/fresh (a d) (rs/== (rs/cons a d) n)))
(rs/defrel (rs/>1o n) (rs/fresh (a ad dd) (rs/== (rs/list* [a ad] dd) n)))

;; b + n + m = r, where b is a carry bit.
(rs/defrel (rs/addero b n m r)
  (rs/conde ((rs/== (rs/q '0) b) (rs/== (rs/nil) m) (rs/== n r))
            ((rs/== (rs/q '0) b) (rs/== (rs/nil) n) (rs/== m r) (rs/poso m))
            ((rs/== (rs/q '1) b) (rs/== (rs/nil) m) (rs/addero (rs/q '0) n (rs/q '(1)) r))
            ((rs/== (rs/q '1) b) (rs/== (rs/nil) n) (rs/poso m) (rs/addero (rs/q '0) (rs/q '(1)) m r))
            ((rs/== (rs/q '(1)) n) (rs/== (rs/q '(1)) m)
             (rs/fresh (a c) (rs/== (rs/list [a c]) r) (rs/full-addero b (rs/q '1) (rs/q '1) a c)))
            ((rs/== (rs/q '(1)) n) (rs/gen-addero b n m r))
            ((rs/== (rs/q '(1)) m) (rs/>1o n) (rs/>1o r) (rs/addero b (rs/q '(1)) n r))
            ((rs/>1o n) (rs/gen-addero b n m r))))

(rs/defrel (rs/gen-addero b n m r)
  (rs/fresh (a c d e x y z)
    (rs/== (rs/cons a x) n)
    (rs/== (rs/cons d y) m) (rs/poso y)
    (rs/== (rs/cons c z) r) (rs/poso z)
    (rs/full-addero b a d c e)
    (rs/addero e x y z)))

;; n + m = k, and n - m = k.
(rs/defrel (rs/+o n m k) (rs/addero (rs/q '0) n m k))
(rs/defrel (rs/-o n m k) (rs/+o m k n))

;; n is the length of l, as a bit list.
(rs/defrel (rs/lengtho l n)
  (rs/conde ((rs/nullo l) (rs/== (rs/nil) n))
            ((rs/fresh (d res) (rs/cdro l d) (rs/+o (rs/q '(1)) res n) (rs/lengtho d res)))))
