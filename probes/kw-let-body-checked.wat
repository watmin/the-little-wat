;; kw-let-body-checked.wat (P5): control for clj-let-body-unchecked.wat, the keyword let.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a "x"]
    (:wat::kernel::println (:wat::core::+ a 1))))
