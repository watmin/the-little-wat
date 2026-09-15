;; splice-list-form-program-body.wat: ~@ over a list-form macro argument, (1 2 3), from a PROGRAM
;; body (the template sits inside a let, so it is evaluated at expansion with the argument
;; bound as a value). Compare splice-vector-form.wat, where a pure template splices [1 2 3].
;; Also: the same with the template under an if, no let.
;; Expected: 6 then 6
(:wat::core::defmacro :u::sum-let [xs <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [ys xs]
    `(:wat::core::+ ~@ys)))
(:wat::core::defmacro :u::sum-if [xs <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::if true
    `(:wat::core::+ ~@xs)
    `0))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::sum-let (1 2 3)))
    (:wat::kernel::println (:u::sum-if (1 2 3)))))
