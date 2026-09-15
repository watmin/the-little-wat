;; macro-arg-data-sym.wat: the same, with a symbol-headed list argument.
;; Expected: u/whatever
(:wat::core::defmacro :u::head-of [form <- :wat::WatAST] -> :wat::WatAST
  `(quote ~(:wat::core::first form)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::head-of (u/whatever 1 2))))
