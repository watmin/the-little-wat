;; F-204, weighing 004 stone 1: closures capturing a RECORD, an ENUM value and a FUNCTION VALUE.
;; Each captured value has syntax; stepping must reach what eval reaches: [4 _], [8 _], [2 _].
;; On the first strike each answered type-mismatch "expected a form".
(:wat::core::defrecord :user::P [a <- :wat::core::i64 b <- :wat::core::i64])
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure :Some [value <- :T] :None [])
(:wat::core::defn :user::inc [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n 1))
(:wat::core::def :user::with-rec
  (:wat::core::let [p (:user::P :a 3 :b 4)] (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n (:user::P/a p)))))
(:wat::core::def :user::with-enum
  (:wat::core::let [o (:user::Opt.Some {:value 7})] (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
    (:wat::core::match o [:user::Opt.Some {:value v} (:wat::core::+ n v)] [:user::Opt.None {} n]))))
(:wat::core::def :user::with-fn
  (:wat::core::let [g :user::inc] (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (g n))))
(:wat::core::defn :user::visit [acc <- :wat::core::i64 form <- :wat::WatAST step <- :wat::eval::StepResult] -> (:wat::eval::WalkStep :- [:wat::core::i64])
  (:wat::eval::WalkStep.Continue {:acc (:wat::i64::+ acc 1)}))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::str (:wat::eval::walk (:wat::core::quote (:user::with-rec 1)) 0 :user::visit)))
    (:wat::kernel::println (:wat::core::str (:wat::eval::walk (:wat::core::quote (:user::with-enum 1)) 0 :user::visit)))
    (:wat::kernel::println (:wat::core::str (:wat::eval::walk (:wat::core::quote (:user::with-fn 1)) 0 :user::visit)))))
