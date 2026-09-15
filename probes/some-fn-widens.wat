;; some-fn-widens.wat: is (:wat::core::Some x) a constructor fn typed Option<T>, so that it
;; widens where the brace form (:wat::core::Option.Some {:value x}) does not (F-019)?
;; Expected: 1
(:wat::core::defn :u::v [] -> (:wat::core::Vector :- [(:wat::core::Option :- [:wat::core::i64])])
  [(:wat::core::Some 1)])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::core::length (:u::v))))
