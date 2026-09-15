;; clj-let-lambda-parametric.wat (L3): a Clojure-spelled let binding a lambda whose parameter
;; type is parametric, and a string. Expected: x
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [o :- (wat.type/Option :- [wat.type/i64])] :- wat.type/bool true)
                 b "x"]
    (wat.kernel/println b)))
