;; some-in-stream-alias-typed-let.wat: workaround candidate. Bind the Some to a let typed
;; Option<i64> first, then cons it; the typealias stays.
;; Expected: 42
(wat.core/typealias :u::Ticks (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])]))
(:wat::core::defn :u::one [] -> :u::Ticks
  (:wat::core::let [x <- (:wat::core::Option :- [:wat::core::i64]) (:wat::core::Option.Some {:value 42})]
    (:wat::stream::cons x (:wat::stream::empty))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::stream::next (:u::one))
    [:wat::stream::NextOutcome.Item {:value v :rest _r}
      (:wat::core::match v
        [:wat::core::Option.Some {:value x} (:wat::kernel::println x)]
        [:wat::core::Option.None {} (:wat::kernel::println "none")])]
    [:wat::stream::NextOutcome.Exhausted {} (:wat::kernel::println "exhausted")]))
