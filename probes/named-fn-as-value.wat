;; named-fn-as-value.wat: passing a NAMED function, spelled as a Clojure/EDN symbol, as a
;; value. The keyword spelling is verified for this (core-seq-walkers.wat passes
;; :ns::identity to map). Expected: true
(wat.core/defn u/same? [a :- :wat::WatAST b :- :wat::WatAST] :- wat.type/bool
  (wat.core/= a b))
(wat.core/defn u/apply2 [f :- [:wat::WatAST :wat::WatAST :-> wat.type/bool]
                         x :- :wat::WatAST
                         y :- :wat::WatAST]
  :- wat.type/bool
  (f x y))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/apply2 u/same? (wat.core/quote pear) (wat.core/quote pear))))
