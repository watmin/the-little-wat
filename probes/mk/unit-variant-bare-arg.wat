;; unit-variant-bare-arg.wat: the bare user-enum unit variant :u::T.Nil as a call ARGUMENT
;; and as a let VALUE, not a fn's return (compare unit-variant-bare.wat).
;; Expected: nil then nil
(:wat::core::defenum :u::T :wat::enum::Pure
  :Leaf [v <- :wat::core::i64]
  :Nil  [])
(:wat::core::defn :u::show [t <- :u::T] -> :wat::core::nil
  (:wat::core::match t
    [:u::T.Leaf {:v v} (:wat::kernel::println v)]
    [:u::T.Nil {} (:wat::kernel::println "nil")]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:u::show :u::T.Nil)
    (:wat::core::let [x :u::T.Nil] (:u::show x))))
