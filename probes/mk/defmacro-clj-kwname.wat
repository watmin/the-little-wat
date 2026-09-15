;; defmacro-clj-kwname.wat: the Clojure-spelled head wat.core/defmacro with a KEYWORD name,
;; called with a keyword head. Discriminates head vs name for defmacro-clj.wat.
;; Expected: 42
(wat.core/defmacro :u::twice [x :- :wat::WatAST] :- :wat::WatAST
  `(wat.core/+ ~x ~x))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (:u::twice 21)))
