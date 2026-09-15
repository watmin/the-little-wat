;; defmacro-clj.wat: defmacro in the Clojure/EDN spelling, called with a symbol head.
;; Expected: 42
(wat.core/defmacro u/twice [x :- :wat::WatAST] :- :wat::WatAST
  `(wat.core/+ ~x ~x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice 21)))
