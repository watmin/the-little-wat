;; type-watast-kw.wat: does the keyword spelling :wat::WatAST work in a `:-` slot of a
;; Clojure/EDN defn? Expected: "symbol"
(wat.core/defn u/kind [x :- :wat::WatAST] :- wat.type/String
  (wat.core/ast-kind x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/kind (wat.core/quote pear))))
