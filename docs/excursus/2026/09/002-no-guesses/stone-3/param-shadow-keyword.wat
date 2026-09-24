;; F-190's program, KEYWORD spelling.
(:wat::core::defn :user::f [x :- :wat::core::String] :- :wat::core::i64
  (:wat::core::+ (:wat::string::length x) (:wat::core::let [x 1] x)))
(:wat::core::defn :user::main [] :- :wat::core::nil (:wat::kernel::println (:user::f "abc")))
