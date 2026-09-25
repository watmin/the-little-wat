;; F-204. Five eval-step! calls on the let-bound-fn case, printing each form. Before the fix every
;; step printed the SAME form: no progress, so :wat::eval::walk never ended.
(:wat::core::defn :user::stepn [f <- :wat::WatAST n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::= n 0) nil
    (:wat::core::match (:wat::eval-step! f)
      [:wat::core::Result.Ok {:value r}
        (:wat::core::match r
          [:wat::eval::StepResult.StepNext {:form g}
            (:wat::core::do (:wat::kernel::println (:wat::core::str g)) (:user::stepn g (:wat::core::- n 1)))]
          [:wat::eval::StepResult.StepTerminal {:value v} (:wat::kernel::println (:wat::string::concat "TERMINAL " (:wat::core::str v)))]
          [:wat::eval::StepResult.AlreadyTerminal {:value v} (:wat::kernel::println (:wat::string::concat "ALREADY " (:wat::core::str v)))])]
      [:wat::core::Result.Err {:error e} (:wat::kernel::println (:wat::string::concat "ERR " (:wat::core::str e)))])))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:user::stepn (:wat::core::quote (:wat::core::let [x 42 f (:wat::core::fn [y <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x y))] (f 1))) 5))
