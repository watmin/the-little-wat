;; A macro declared to return an enum value, and the same value written by hand.
(:wat::core::defmacro :user::some7 [] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::Option.Some {:value 7}))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::str (:user::some7)))
    (:wat::kernel::println (:wat::core::str (:wat::core::Option.Some {:value 7})))))
