;; probes/java/variant-equality.wat: can two different variants of one enum be compared with
;; =? A variant constructor keeps its narrowed type (F-019), so (Anchovy) is a FishD.Anchovy.
;; Three forms, each its own program run: inline, let-bound, and through helpers whose
;; declared return type is the enum. Only the last is expected to type-check.

(:wat::core::defenum :probe::FishD :wat::enum::Pure :Anchovy [] :Tuna [])

(:wat::core::defn :probe::anchovy [] -> :probe::FishD (:probe::FishD.Anchovy {}))
(:wat::core::defn :probe::tuna [] -> :probe::FishD (:probe::FishD.Tuna {}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a (:probe::FishD.Anchovy {})
                    t (:probe::FishD.Tuna {})]
    (:wat::kernel::println (:wat::core::if (:wat::core::= a t) "let-bound: equal" "let-bound: not equal"))))
