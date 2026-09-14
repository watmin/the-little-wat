;; type-watast-slash.wat: is the WatAST type spelled `wat/WatAST` in the Clojure/EDN
;; spelling? (`wat.type/WatAST` resolves to :wat::core::WatAST, which does not exist.)
;; Expected: "symbol"
(wat.core/defn u/kind [x :- wat/WatAST] :- wat.type/String
  (wat.core/ast-kind x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/kind (wat.core/quote pear))))
