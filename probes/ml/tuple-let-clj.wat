;; tuple-let-clj.wat: the Clojure-spelled let destructuring a tuple, [[a b] t]. F-024 checks a
;; Clojure let's binding vector as a vector literal. Expected: 3
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [[a b] (:wat::core::Tuple 1 2)]
    (wat.kernel/println (wat.core/+ a b))))
