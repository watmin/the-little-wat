;; probes/koans/map-as-function.wat: in Clojure a map is a function of its keys. Is a map literal
;; in call position refused by the checker, or does it pass and fail at runtime?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write ({:x 1 :y 2} :x))))
