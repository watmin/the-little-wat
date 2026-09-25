;; F-206. A macro body is not type-checked: an integer handed to a string function passes
;; `wat --check` in an arm that never runs. Measured at wat-rs 75fcc7638: check=0, run prints 3.
(:wat::core::defmacro :my::bad [] -> :wat::WatAST
  (:wat::core::if (:wat::core::= 1 1) `(:wat::core::+ 1 2) (:wat::string::length 7)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:my::bad)))
