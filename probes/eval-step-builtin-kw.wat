;; F-204. :wat::eval::walk over one case; the walk's terminal must equal eval's answer.
;; Expected: Ok [3 1].
(:wat::core::defn :user::add1 [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n 1))
(:wat::core::defn :user::sum-to [n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) acc (:user::sum-to (:wat::core::- n 1) (:wat::core::+ acc n))))
(:wat::core::def :user::adder10
  (:wat::core::let [k 10] (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n k))))
(:wat::core::defn :user::visit [acc <- :wat::core::i64 form <- :wat::WatAST step <- :wat::eval::StepResult] -> (:wat::eval::WalkStep :- [:wat::core::i64])
  (:wat::eval::WalkStep.Continue {:acc (:wat::i64::+ acc 1)}))
(:wat::core::defn :user::show [label <- :wat::core::String f <- :wat::WatAST] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label (:wat::string::concat "  walk=" (:wat::core::str (:wat::eval::walk f 0 :user::visit))))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:user::show "b0 builtin kw        " (:wat::core::quote (:wat::core::+ 1 2))))
