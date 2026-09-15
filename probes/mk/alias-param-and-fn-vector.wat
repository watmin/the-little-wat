;; alias-param-and-fn-vector.wat: (1) a typealias naming a PARAMETRIC type; (2) a Vector
;; holding functions, folded over. miniKanren's conde takes a list of goals.
;; Expected: 42 then 7
(wat.core/typealias :u::Ticks (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])]))
(wat.core/defn u/one [] :- :u::Ticks
  (:wat::stream::cons (:wat::core::Option.Some {:value 42}) (:wat::stream::empty)))
(wat.core/defn u/apply-all [fs :- (wat.type/Vector :- [[wat.type/i64 :-> wat.type/i64]]) x :- wat.type/i64] :- wat.type/i64
  (:wat::core::foldl (:wat::core::fn [acc <- :wat::core::i64 f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64 (f acc))
                     x fs))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (:wat::core::match (:wat::stream::next (u/one))
      [:wat::stream::NextOutcome.Item {:value v :rest _r}
        (:wat::core::match v
          [:wat::core::Option.Some {:value x} (wat.kernel/println x)]
          [:wat::core::Option.None {} (wat.kernel/println "none")])]
      [:wat::stream::NextOutcome.Exhausted {} (wat.kernel/println "exhausted")])
    (wat.kernel/println (u/apply-all [(wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
                                      (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/* n 2))]
                                     (wat.core/+ 1 1)))))
