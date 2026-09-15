;; probes/learner/hashmap-i64-f64.wat: the gradient table of the Learner's autodiff, keyed by
;; a leaf dual's position: assoc, get with a default, and the literal for an empty map.

(:wat::core::typealias :probe::Sigma (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64]))

(:wat::core::defn :probe::add [s <- :probe::Sigma k <- :wat::core::i64 z <- :wat::core::f64] -> :probe::Sigma
  (:wat::core::assoc s k (:wat::core::+ z (:probe::at s k))))

(:wat::core::defn :probe::at [s <- :probe::Sigma k <- :wat::core::i64] -> :wat::core::f64
  (:wat::core::match (:wat::core::get s k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0.0]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s0 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64])
                    s1 (:probe::add s0 0 1.5)
                    s2 (:probe::add s1 0 2.0)
                    s3 (:probe::add s2 1 7.0)]
    (:wat::kernel::println (:wat::string::concat (:wat::f64::to-string (:probe::at s3 0)) " "
                                                 (:wat::f64::to-string (:probe::at s3 1)) " "
                                                 (:wat::f64::to-string (:probe::at s3 2))))))
