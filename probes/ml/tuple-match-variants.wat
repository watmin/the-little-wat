;; tuple-match-variants.wat: ML's patterns on a pair of variants, (Shrimp, Sundae), written
;; as a tuple pattern whose elements are nested variant sub-patterns. Every combination is
;; explicit (no `_`). Expected: shrimp-sundae, then other
(:wat::core::defenum :u::Meza :wat::enum::Pure :Shrimp [] :Hummus [])
(:wat::core::defenum :u::Dessert :wat::enum::Pure :Sundae [] :Torte [])
(:wat::core::defn :u::pair [t <- (:wat::core::Tuple :- [:u::Meza :u::Dessert])] -> :wat::core::String
  (:wat::core::match t
    [([:u::Meza.Shrimp {}] [:u::Dessert.Sundae {}]) "shrimp-sundae"]
    [([:u::Meza.Shrimp {}] [:u::Dessert.Torte {}]) "other"]
    [([:u::Meza.Hummus {}] [:u::Dessert.Sundae {}]) "other"]
    [([:u::Meza.Hummus {}] [:u::Dessert.Torte {}]) "other"]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::pair (:wat::core::Tuple (:u::Meza.Shrimp {}) (:u::Dessert.Sundae {}))))
    (:wat::kernel::println (:u::pair (:wat::core::Tuple (:u::Meza.Hummus {}) (:u::Dessert.Sundae {}))))))
