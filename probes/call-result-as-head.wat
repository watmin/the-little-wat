;; call-result-as-head.wat: calling the RESULT of a call directly, ((eq?-c 'pear) 'pear),
;; the way the book writes it. Uses the keyword fn literal so only the call shape is new.
;; Expected: true
(wat.core/defn u/eq?-c [a :- :wat::WatAST] :- [:wat::WatAST :-> wat.type/bool]
  (:wat::core::fn [x <- :wat::WatAST] -> :wat::core::bool
    (:wat::core::= x a)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println ((u/eq?-c (wat.core/quote pear)) (wat.core/quote pear))))
