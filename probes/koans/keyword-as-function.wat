;; probes/koans/keyword-as-function.wat: in Clojure a keyword is a function of maps, so
;; (:y {:x 1 :y 2}) is 2 and (:z {:x 1 :y 2}) is nil. What does wat answer?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::edn::write (:y {:x 1 :y 2})))
    (:wat::kernel::println (:wat::edn::write (:z {:x 1 :y 2})))))
