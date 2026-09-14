;; Workaround for typealias-clj.wat: the Clojure-spelled form with a KEYWORD name, then that
;; alias in :- slots. Expected: "symbol"
(wat.core/typealias :u::Sexp :wat::WatAST)
(wat.core/defn u/kind [x :- :u::Sexp] :- wat.type/String
  (wat.core/ast-kind x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/kind 'pear)))
