;; unknown-ns-in-fn.wat: F-007 scope. A NAMESPACED name that exists nowhere (u/zzz), inside
;; a let-bound fn body. The resolver catches unknown namespaced symbols elsewhere
;; (F-005's wat/WatAST case). Does it catch this one?
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
         (u/zzz n))]
    (:wat::kernel::println (g 5))))
