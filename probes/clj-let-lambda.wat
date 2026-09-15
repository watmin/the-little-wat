;; clj-let-lambda.wat (L2): a Clojure-spelled let binding a lambda and a string.
;; Expected: x
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 n)
                 b "x"]
    (wat.kernel/println b)))
