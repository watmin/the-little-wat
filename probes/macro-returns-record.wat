;; A macro declared to return a record, and the same record written by hand.
(:wat::core::defrecord :user::P [a <- :wat::core::i64 b <- :wat::core::i64])
(:wat::core::defmacro :user::mk [] -> :user::P
  (:user::P :a 3 :b 4))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::str (:user::mk)))
    (:wat::kernel::println (:wat::core::str (:user::P :a 3 :b 4)))))
