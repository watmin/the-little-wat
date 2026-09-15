;; macro-template-kw-quote.wat: macro-arg-variants.wat and macro-arg-program-body.wat with the
;; template's bare `quote` replaced by the keyword :wat::core::quote. If these pass, a bare
;; `quote` introduced by a template is not recognized as quote after expansion.
;; Expected: (:u::whatever 1 2), (u/whatever 1 2), :u::whatever, u/whatever
(:wat::core::defmacro :u::m1 [form <- :wat::WatAST] -> :wat::WatAST
  `(:wat::core::quote ~form))
(:wat::core::defmacro :u::m2 [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [h (:wat::core::first form)]
    `(:wat::core::quote ~h)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::m1 (:u::whatever 1 2)))
    (:wat::kernel::println (:u::m1 (u/whatever 1 2)))
    (:wat::kernel::println (:u::m2 (:u::whatever 1 2)))
    (:wat::kernel::println (:u::m2 (u/whatever 1 2)))))
