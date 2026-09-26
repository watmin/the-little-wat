;; A captured value that is itself an unnamed closure. That closure captures `k`,
;; so stepping writes its `fn` form with `k` already substituted. The walk's
;; terminal is eval's answer.
;; Expected: 4, stepped.
(:wat::core::defn :user::visit [acc <- :wat::core::i64 form <- :wat::WatAST step <- :wat::eval::StepResult] -> (:wat::eval::WalkStep :- [:wat::core::i64])
  (:wat::eval::WalkStep.Continue {:acc (:wat::i64::+ acc 1)}))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [form (:wat::core::quote
                     (:wat::core::let [k 3]
                       (:wat::core::let [inner (:wat::core::fn [z <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ z k))]
                         (:wat::core::let [outer (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (inner n))]
                           (outer 1)))))]
    (:wat::core::do
      (:wat::kernel::println (:wat::core::str (:wat::eval::walk form 0 :user::visit)))
      (:wat::kernel::println (:wat::core::str
        (:wat::core::match (:wat::eval-ast! form)
          [:wat::core::Result.Ok {:value n} n]
          [:wat::core::Result.Err {:error e} e]))))))
