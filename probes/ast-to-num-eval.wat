;; ast-to-num-eval.wat: WatAST int → i64 by evaluating the literal node with eval-ast!.
;; (The stdlib itself goes through a string instead: wat/core.wat:536.)
;; Expected: 12
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [node (wat.core/first (wat.core/quote (5 6)))
                 v    (:wat::core::Result/expect (:wat::eval-ast! node) "eval an int literal")]
    (wat.kernel/println (wat.core/+ v 7))))
