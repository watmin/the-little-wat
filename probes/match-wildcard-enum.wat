;; match-wildcard-enum.wat: a match on a user enum with a `_` arm standing for the variants it
;; does not name. The builder's rule is that an arm cannot be forgotten. Allowed?
;; Expected (if allowed): other
(:wat::core::defenum :u::Veg :wat::enum::Pure
  :Onion [] :Lamb [] :Tomato [])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::Veg.Lamb {})
    [:u::Veg.Onion {} (:wat::kernel::println "onion")]
    [_ (:wat::kernel::println "other")]))
