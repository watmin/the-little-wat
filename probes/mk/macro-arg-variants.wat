;; macro-arg-variants.wat: which uses of a list-valued macro parameter evaluate it?
;; m1 splices the whole parameter under quote; m2 takes its first element in a let OUTSIDE
;; the quasiquote. Expected: (:u::whatever 1 2) then :u::whatever
(:wat::core::defmacro :u::m1 [form <- :wat::WatAST] -> :wat::WatAST
  `(quote ~form))
(:wat::core::defmacro :u::m2 [form <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [h (:wat::core::first form)]
    `(quote ~h)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::m1 (:u::whatever 1 2)))
    (:wat::kernel::println (:u::m2 (:u::whatever 1 2)))))
