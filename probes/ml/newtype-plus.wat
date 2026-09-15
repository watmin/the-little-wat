;; newtype-plus.wat: newtype-value.wat's (:u::N 5), plus. Expected: refused at startup (a newtype is not its inner type)
(:wat::core::newtype :u::N :wat::core::i64)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::+ (:u::N 5) 1)))
