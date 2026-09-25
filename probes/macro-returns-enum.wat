;; A macro declared to return an enum value, and the same value written by hand.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure :Some [value <- :T] :None [])
(:wat::core::defmacro :user::some7 [] -> (:user::Opt :- [:wat::core::i64])
  (:user::Opt.Some {:value 7}))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::str (:user::some7)))
    (:wat::kernel::println (:wat::core::str (:user::Opt.Some {:value 7})))))
