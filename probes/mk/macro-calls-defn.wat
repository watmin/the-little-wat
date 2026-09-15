;; macro-calls-defn.wat: a macro calls a user defn at expansion time.
;; Expected: 3
(:wat::core::defn :u::wrap [x <- :wat::WatAST] -> :wat::WatAST
  `(:wat::core::+ ~x 1))
(:wat::core::defmacro :u::inc [x <- :wat::WatAST] -> :wat::WatAST
  (:u::wrap x))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::inc 2)))
