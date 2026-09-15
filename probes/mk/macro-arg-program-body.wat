;; macro-arg-program-body.wat: a PROGRAM-body macro (not a template) takes the first element of
;; its list parameter in a let, then builds its expansion. Keyword- and symbol-headed args.
;; Expected: :u::whatever then u/whatever
(:wat::core::defmacro :u::m2 [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [h (:wat::core::first form)]
    `(quote ~h)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::m2 (:u::whatever 1 2)))
    (:wat::kernel::println (:u::m2 (u/whatever 1 2)))))
