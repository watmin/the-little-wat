;; some-in-stream-no-alias.wat: the same stream as alias-param-and-fn-vector.wat, with the full
;; type written out instead of a typealias. Isolates alias vs variant-constructor typing.
;; Expected: 42
(:wat::core::defn :u::one [] -> (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])])
  (:wat::stream::cons (:wat::core::Option.Some {:value 42}) (:wat::stream::empty)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::stream::next (:u::one))
    [:wat::stream::NextOutcome.Item {:value v :rest _r}
      (:wat::core::match v
        [:wat::core::Option.Some {:value x} (:wat::kernel::println x)]
        [:wat::core::Option.None {} (:wat::kernel::println "none")])]
    [:wat::stream::NextOutcome.Exhausted {} (:wat::kernel::println "exhausted")]))
