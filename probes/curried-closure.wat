;; curried-closure.wat: a Clojure/EDN-spelled fn that returns a closure over its argument,
;; like the book's eq?-c. Called through a let binding. Expected: true then false
(wat.core/defn u/eq?-c [a :- :wat::WatAST] :- [:wat::WatAST :-> wat.type/bool]
  (wat.core/fn [x :- :wat::WatAST] :- wat.type/bool
    (wat.core/= x a)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [pear? (u/eq?-c (wat.core/quote pear))]
    (wat.core/do
      (wat.kernel/println (pear? (wat.core/quote pear)))
      (wat.kernel/println (pear? (wat.core/quote plum))))))
