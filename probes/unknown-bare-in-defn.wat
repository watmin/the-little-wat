;; unknown-bare-in-defn.wat: F-007 scope. A call to a name that exists nowhere, inside a
;; top-level defn body. Does startup catch it?
(:wat::core::defn :u::f [n <- :wat::core::i64] -> :wat::core::i64
  (zzz n))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::f 5)))
