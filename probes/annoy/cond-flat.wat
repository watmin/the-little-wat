;; Clojure's FLAT cond: (cond test expr test expr :else expr). wat's chapters use
;; parenthesised clauses. Expected in Clojure: "b"
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/cond (wat.core/= 1 2) "a" (wat.core/= 1 1) "b" :else "c")))
