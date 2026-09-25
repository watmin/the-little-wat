;; Nobody calls this macro. The untaken arm still has a type error, and
;; --check refuses it.
(:wat::core::defmacro :user::unused [] -> :wat::WatAST
  (:wat::core::if (:wat::core::= 1 1)
    `(:wat::core::+ 1 2)
    (:wat::string::length 7)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println 1))
