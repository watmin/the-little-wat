;; probes/koans/rest-of-empty.wat: Clojure's (rest '()) and (rest []) are both (). What are
;; wat's, for an empty Vector and for a quoted empty list?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::edn::write (:wat::core::rest (:wat::core::Vector :- [:wat::core::i64]))))
    (:wat::kernel::println (:wat::edn::write (:wat::core::rest '())))))
