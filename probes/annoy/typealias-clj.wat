;; A typealias in the Clojure/EDN spelling, to name :wat::WatAST once instead of on every
;; parameter. Expected: "symbol"
(wat.core/typealias u/Sexp :wat::WatAST)
(wat.core/defn u/kind [x :- u/Sexp] :- wat.type/String
  (wat.core/ast-kind x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/kind (wat.core/quote pear))))
