;; unknown-bare-in-main.wat: F-007 scope. A call to a name that exists nowhere, directly in
;; main's body, with no fn literal involved. Does startup catch it?
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (zzz 5)))
