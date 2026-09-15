;; option-stream-bare-none.wat: a lazy stream of Option values, where None is a pause
;; (miniKanren's suspension). None is written as the bare unit variant :wat::core::Option.None.
;; Expected: 42
(:wat::core::defn :u::ticks [n <- :wat::core::i64] -> (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])])
  (:wat::stream::lazy
    (:wat::core::if (:wat::core::= n 0)
      (:wat::stream::cons (:wat::core::Option.Some {:value 42}) (:wat::stream::empty))
      (:wat::stream::cons :wat::core::Option.None (:u::ticks (:wat::core::- n 1))))))
(:wat::core::defn :u::first-some [s <- (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])])] -> :wat::core::i64
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Item {:value v :rest r}
      (:wat::core::match v
        [:wat::core::Option.Some {:value x} x]
        [:wat::core::Option.None {} (:u::first-some r)])]
    [:wat::stream::NextOutcome.Exhausted {} -1]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::first-some (:u::ticks 3))))
