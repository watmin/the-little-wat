;; unit-variant-call.wat: the same, with the unit variant CALLED with no arguments, (:u::T.Nil),
;; the spelling its bare type [:-> :u::T.Nil] suggests.
;; Expected: nil
(:wat::core::defenum :u::T :wat::enum::Pure
  :Leaf [v <- :wat::core::i64]
  :Nil  [])
(:wat::core::defn :u::nil [] -> :u::T (:u::T.Nil))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::nil)
    [:u::T.Leaf {:v v} (:wat::kernel::println v)]
    [:u::T.Nil {} (:wat::kernel::println "nil")]))
