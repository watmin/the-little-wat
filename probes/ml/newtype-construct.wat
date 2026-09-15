;; newtype-construct.wat: newtype-value.wat's (:u::N 5), construct. Expected: built
(:wat::core::newtype :u::N :wat::core::i64)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n (:u::N 5)] (:wat::kernel::println "built")))
