;; F-206. The declaration lies and nothing notices: declared `-> :wat::WatAST`, body an i64.
;; Measured at wat-rs 75fcc7638: check=0, prints 42. `-> :wat::core::i64` is refused at definition.
(:wat::core::defmacro :my::answer [] -> :wat::WatAST 42)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:my::answer)))
