;; name-leading-star.wat: is a name starting with `*` legal, like the book's *const? A
;; trailing star (ls/rember*) works. Expected if legal: true
(wat.core/defn u/*const [x :- wat.type/i64] :- wat.type/bool
  (wat.core/= x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/*const 1)))
