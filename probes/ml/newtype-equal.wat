;; newtype-equal.wat: newtype-value.wat's (:u::N 5), equal. Expected: true
(:wat::core::newtype :u::N :wat::core::i64)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::= (:u::N 5) (:u::N 5))))
