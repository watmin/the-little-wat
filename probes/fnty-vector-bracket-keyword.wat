;; F-203. A function type as a collection's type argument, spelled: bracket-keyword. `wat --check` accepted every
;; spelling; before the fix the RUNTIME refused the bracket forms as "malformed :wat::core::Vector".
;; Expected output: 11.
;; keyword spelling of q3
(:wat::core::defn :user::inc [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n 1))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [fs (:wat::core::Vector :- [[:wat::core::i64 :-> :wat::core::i64]] :user::inc)]
    (:wat::kernel::println ((:wat::core::nth fs 0) 10))))
