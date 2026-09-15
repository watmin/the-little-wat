;; clj-let-mixed.wat (L1): a Clojure-spelled let binding values of different types.
;; Is the binding vector type-checked as a vector literal? Expected: x
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a 1
                 b "x"]
    (wat.kernel/println b)))
