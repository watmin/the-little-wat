;; F-014 scope: a Clojure-spelled defn whose body returns a String while it declares
;; :- wat.type/i64. Caught at startup?
(wat.core/defn u/f [] :- wat.type/i64
  "pear")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/f)))
