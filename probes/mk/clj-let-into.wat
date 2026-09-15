;; clj-let-into.wat: variant C, no miniKanren. A Clojure-spelled let whose bindings include
;; an empty vector and an (into [] (take …)). Expected: 2
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a [1 2 3]
                 b (:wat::core::into [] (:wat::core::take a 2))]
    (wat.kernel/println (wat.core/length b))))
