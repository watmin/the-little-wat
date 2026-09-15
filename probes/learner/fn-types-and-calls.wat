;; probes/learner/fn-types-and-calls.wat: two shapes the Learner port leans on. A
;; two-argument function type, [A B :-> R], held in an Impure enum; and calling the result of
;; an expression directly, ((f x) y), the book's ((line x) theta).

(:wat::core::typealias :probe::Sigma (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64]))

(:wat::core::defenum :probe::Link :wat::enum::Impure
  :Const []
  :Step [f <- [:wat::core::f64 :probe::Sigma :-> :probe::Sigma]])

(:wat::core::defn :probe::adder [x <- :wat::core::f64] -> [:wat::core::f64 :-> :wat::core::f64]
  (:wat::core::fn [y <- :wat::core::f64] -> :wat::core::f64 (:wat::core::+ x y)))

(:wat::core::defn :probe::run [l <- :probe::Link z <- :wat::core::f64 s <- :probe::Sigma] -> :probe::Sigma
  (:wat::core::match l
    [:probe::Link.Const {} s]
    [:probe::Link.Step {:f f} (f z s)]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [step (:probe::Link.Step {:f (:wat::core::fn [z <- :wat::core::f64 s <- :probe::Sigma] -> :probe::Sigma (:wat::core::assoc s 0 z))})
                    s (:probe::run step 2.5 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64]))]
    (:wat::core::do
      (:wat::kernel::println (:wat::f64::to-string ((:probe::adder 1.5) 2.0)))
      (:wat::kernel::println (:wat::i64::to-string (:wat::core::length s))))))
