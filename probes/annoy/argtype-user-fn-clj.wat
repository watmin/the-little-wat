;; F-014 scope: a WRONG ARGUMENT TYPE (a string for an i64) to a user function, in the
;; Clojure/EDN spelling. Caught at startup (exit 3) or only at runtime?
(wat.core/defn u/add1 [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/add1 "pear")))
