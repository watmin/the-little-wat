;; splice-vector-form.wat: ~@ over a macro argument that is a VECTOR form, [1 2 3].
;; Control: splice-list-form.wat, the same with a list form (1 2 3).
;; Expected: 6
(:wat::core::defmacro :u::sum [xs <- :wat::WatAST] -> :wat::WatAST
  `(:wat::core::+ ~@xs))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::sum [1 2 3])))
