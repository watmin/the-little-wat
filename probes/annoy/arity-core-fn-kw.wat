;; F-014 discriminator: arity-core-fn.wat in the KEYWORD spelling. Startup or runtime?
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length [1 2] [3])))
