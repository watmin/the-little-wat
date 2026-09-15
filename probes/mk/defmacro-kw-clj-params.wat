;; defmacro-kw-clj-params.wat: the keyword head :wat::core::defmacro with a symbol name and
;; Clojure-style params, called with a symbol head.
;; Expected: 42
(:wat::core::defmacro u/twice [x :- :wat::WatAST] :- :wat::WatAST
  `(wat.core/+ ~x ~x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice 21)))
