;; match-missing-arm.wat: a match on a user enum that names two of its three variants and has
;; no `_` arm. Expected: refused at startup (exhaustiveness).
(:wat::core::defenum :u::Veg :wat::enum::Pure
  :Onion [] :Lamb [] :Tomato [])
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::Veg.Lamb {})
    [:u::Veg.Onion {} (:wat::kernel::println "onion")]
    [:u::Veg.Lamb {} (:wat::kernel::println "lamb")]))
