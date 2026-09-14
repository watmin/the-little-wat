;; F-014 scope: a USER function called with the wrong number of arguments. Caught at
;; startup (exit 3) or only at runtime (exit 1)?
(wat.core/defn u/add1 [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/add1 1 2)))
