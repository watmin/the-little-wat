;; ctor-kw-concrete.wat: F-009 control. The KEYWORD constructor with CONCRETE type
;; arguments, no generics. If this works, F-009's generic failure is about type variables
;; reaching the constructor at runtime.
;; Expected: 0
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64])]
    (:wat::kernel::println (:wat::core::length m))))
