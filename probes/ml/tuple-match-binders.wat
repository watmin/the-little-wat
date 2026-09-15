;; tuple-match-binders.wat: a match arm that destructures a 2-tuple by position,
;; [(m d) body], at the top of the arm. Expected: 3
(:wat::core::defn :u::sum [t <- (:wat::core::Tuple :- [:wat::core::i64 :wat::core::i64])] -> :wat::core::i64
  (:wat::core::match t
    [(a b) (:wat::core::+ a b)]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::sum (:wat::core::Tuple 1 2))))
