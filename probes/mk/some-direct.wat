;; some-direct.wat: control. (Option.Some {:value 42}) returned from a fn declared Option<i64>.
;; Expected: 42
(:wat::core::defn :u::one [] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::Option.Some {:value 42}))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::one)
    [:wat::core::Option.Some {:value x} (:wat::kernel::println x)]
    [:wat::core::Option.None {} (:wat::kernel::println "none")]))
