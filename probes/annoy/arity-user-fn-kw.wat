;; F-014 discriminator: arity-user-fn.wat, all in the KEYWORD spelling. Caught at startup
;; (exit 3) or only at runtime (exit 1)?
(:wat::core::defn :u::add1 [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::add1 1 2)))
