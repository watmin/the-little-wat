;; num-to-ast.wat: i64 → WatAST, the direction Little Schemer ch 4 needs to build tuples
;; (lists of numbers). Does quasiquote with ~n make a number node equal to a quoted one?
;; Expected: true true
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n    5
                 more (wat.core/quote (6 7))]
    (wat.core/do
      (wat.kernel/println (wat.core/= (wat.core/quasiquote ~n) (wat.core/quote 5)))
      (wat.kernel/println (wat.core/= (wat.core/quasiquote (~n ~@more)) (wat.core/quote (5 6 7)))))))
