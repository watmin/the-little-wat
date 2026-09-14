;; F-014 scope: the same wrong argument type, in the KEYWORD spelling.
(:wat::core::defn :u::add1 [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::add1 "pear")))
