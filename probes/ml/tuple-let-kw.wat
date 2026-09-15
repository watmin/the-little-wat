;; tuple-let-kw.wat: the keyword let destructuring a tuple, [[a b] t]. Expected: 3
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [[a b] (:wat::core::Tuple 1 2)]
    (:wat::kernel::println (:wat::core::+ a b))))
