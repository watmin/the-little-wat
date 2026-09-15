;; match-binder-catchall.wat: a match on a user enum whose last arm is a bare binder, [v body],
;; binding whatever variant is left. Does it count as covering the unnamed variants?
;; Expected (if allowed): other
(:wat::core::defenum :u::Veg :wat::enum::Pure
  :Onion [] :Lamb [] :Tomato [])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::Veg.Lamb {})
    [:u::Veg.Onion {} (:wat::kernel::println "onion")]
    [v (:wat::kernel::println "other")]))
