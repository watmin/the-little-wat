;; A macro whose body builds a vector of integers from forms that evaluate
;; at expansion, declared as that vector. The same vector written by hand.
(:wat::core::defmacro :user::pair [] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::Vector :- [:wat::core::i64] (:wat::core::+ 1 2) (:wat::core::+ 3 1)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::str (:user::pair)))
    (:wat::kernel::println (:wat::core::str (:wat::core::Vector :- [:wat::core::i64] 3 4)))))
