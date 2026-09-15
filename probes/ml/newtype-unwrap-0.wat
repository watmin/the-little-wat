;; newtype-unwrap-0.wat: can a newtype value be unwrapped? Guess: the accessor
;; (:u::N/0 n). wat-rs has no .wat use of newtype and no unwrap in sight.
;; Expected (if this is the accessor): 5
(:wat::core::newtype :u::N :wat::core::i64)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n (:u::N 5)]
    (:wat::kernel::println (:u::N/0 n))))
