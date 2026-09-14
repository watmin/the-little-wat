;; type-watast-core.wat: the repro for FINDINGS F-005 and F-006. `wat.type/WatAST`
;; resolves to :wat::core::WatAST, which does not exist; the real type is :wat::WatAST.
;; Expected: a StartupError. Read its :location. F-006 is that it names the checker's own
;; Rust source instead of this file.
(wat.core/defn u/kind [x :- wat.type/WatAST] :- wat.type/String
  (wat.core/ast-kind x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/kind (wat.core/quote pear))))
