;; newtype-value.wat: how is a newtype value built and taken apart? wat-rs tests only the
;; declaration. First guess: the type name called with the inner value, (:u::N 5).
;; Expected (if that is the spelling): #u/N 5 or similar
(:wat::core::newtype :u::N :wat::core::i64)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::N 5)))
