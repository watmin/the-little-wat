;; unit-variant-bare.wat: how is a bare user-enum unit variant typed? The bare
;; :wat::core::Option.None is a value (option-stream-bare-none.wat). Here :u::T.Nil, bare,
;; is returned from a fn declared :u::T.
;; Expected: nil
(:wat::core::defenum :u::T :wat::enum::Pure
  :Leaf [v <- :wat::core::i64]
  :Nil  [])
(:wat::core::defn :u::nil [] -> :u::T :u::T.Nil)
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:u::nil)
    [:u::T.Leaf {:v v} (:wat::kernel::println v)]
    [:u::T.Nil {} (:wat::kernel::println "nil")]))
