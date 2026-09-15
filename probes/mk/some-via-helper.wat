;; some-via-helper.wat: workaround candidate. A generic helper fn whose declared return is
;; Option<T> widens Option.Some<T> at the fn boundary, where subsumption works (some-direct.wat).
;; Expected: 42 then 1
(wat.core/defn u/some :- [T] [x :- T] :- (wat.type/Option :- [T]) (:wat::core::Option.Some {:value x}))
(:wat::core::defn :u::one [] -> (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])])
  (:wat::stream::cons (u/some 42) (:wat::stream::empty)))
(:wat::core::defn :u::v [] -> (:wat::core::Vector :- [(:wat::core::Option :- [:wat::core::i64])])
  [(u/some 1)])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::core::match (:wat::stream::next (:u::one))
      [:wat::stream::NextOutcome.Item {:value v :rest _r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value x} (:wat::kernel::println x)]
          [:wat::core::Option.None {} (:wat::kernel::println "none")])]
      [:wat::stream::NextOutcome.Exhausted {} (:wat::kernel::println "exhausted")])
    (:wat::kernel::println (:wat::core::length (:u::v)))))
