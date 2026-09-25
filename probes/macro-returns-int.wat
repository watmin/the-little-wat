;; A macro declared to return an i64, and the same integer written by hand.
(:wat::core::defmacro :user::answer [] -> :wat::core::i64
  42)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:user::answer))
    (:wat::kernel::println 42)))
