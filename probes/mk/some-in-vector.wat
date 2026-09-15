;; some-in-vector.wat: (Option.Some {..}) inside a Vector literal, declared Vector<Option<i64>>.
;; Expected: 1
(:wat::core::defn :u::v [] -> (:wat::core::Vector :- [(:wat::core::Option :- [:wat::core::i64])])
  [(:wat::core::Option.Some {:value 1})])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length (:u::v))))
