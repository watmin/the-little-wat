;; constructor-as-fn.wat: ML's constructors are functions: `fun hot_maker(x) = Hot` returns
;; the constructor Hot : bool -> bool_or_int. Can a wat variant constructor be passed where a
;; [bool :-> B] is expected? Expected (if so): #u/B.Hot {:v true}
(:wat::core::defenum :u::B :wat::enum::Pure
  :Hot  [v <- :wat::core::bool]
  :Cold [n <- :wat::core::i64])
(:wat::core::defn :u::apply-to-true [f <- [:wat::core::bool :-> :u::B]] -> :u::B
  (f true))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::apply-to-true :u::B.Hot)))
