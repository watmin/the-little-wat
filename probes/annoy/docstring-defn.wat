;; A Clojure docstring on defn. Expected in Clojure: 8
(wat.core/defn u/add1 "adds one" [x :- wat.type/i64] :- wat.type/i64
  (wat.core/+ x 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/add1 7)))
