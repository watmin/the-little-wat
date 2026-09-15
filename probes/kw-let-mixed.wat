;; kw-let-mixed.wat (P1): control for clj-let-mixed.wat, the KEYWORD let binding an i64 and a
;; String. Expected: x
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a 1
                    b "x"]
    (:wat::kernel::println b)))
