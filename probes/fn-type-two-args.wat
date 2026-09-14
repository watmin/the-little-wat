;; fn-type-two-args.wat: a function parameter taking TWO arguments, as the collectors of
;; Little Schemer ch 8 need. Type guessed as [A B :-> C]. Expected: true
(wat.core/defn u/call2 [col :- [:wat::WatAST :wat::WatAST :-> wat.type/bool]
                        x   :- :wat::WatAST
                        y   :- :wat::WatAST]
  :- wat.type/bool
  (col x y))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (u/call2 (:wat::core::fn [a <- :wat::WatAST b <- :wat::WatAST] -> :wat::core::bool (:wat::core::= a b))
             (wat.core/quote pear) (wat.core/quote pear))))
