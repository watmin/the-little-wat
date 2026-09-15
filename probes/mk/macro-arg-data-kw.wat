;; macro-arg-data-kw.wat: a macro takes the first element of a keyword-headed list ARGUMENT,
;; as data. Is the argument form evaluated at expansion time?
;; Expected: :u::whatever
(:wat::core::defmacro :u::head-of [form <- :wat::WatAST] -> :wat::WatAST
  `(quote ~(:wat::core::first form)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::head-of (:u::whatever 1 2))))
