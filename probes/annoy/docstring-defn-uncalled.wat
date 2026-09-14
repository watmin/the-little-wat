;; A docstring defn that is never called. If this exits 0, the malformed-for-wat definition
;; was accepted silently: nothing at the defn says it did not register.
(wat.core/defn u/add1 "adds one" [x :- wat.type/i64] :- wat.type/i64
  (wat.core/+ x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println "ran"))
