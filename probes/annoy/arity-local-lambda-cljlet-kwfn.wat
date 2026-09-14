;; F-014 2x2, corner: Clojure let + keyword fn.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 x)]
    (wat.kernel/println (f 1 2))))
