;; recursive-enum.wat: a Pure enum whose variant holds its own enum type. miniKanren terms
;; need pairs with variable tails, (a . d), which quoted lists cannot express. A recursive
;; enum is the clean representation. The wat-rs survey found none anywhere.
;; Expected: 2 then true
(:wat::core::defenum :u::Term :wat::enum::Pure
  :Atom [v <- :wat::WatAST]
  :Var  [n <- :wat::core::i64]
  :Pair [a <- :u::Term  d <- :u::Term]
  :Nil  [])
(:wat::core::defn :u::len [t <- :u::Term] -> :wat::core::i64
  (:wat::core::match t
    [:u::Term.Pair {:a _a :d d} (:wat::core::+ 1 (:u::len d))]
    [_ 0]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:u::Term.Pair {:a (:u::Term.Atom {:v 'pear})
                                      :d (:u::Term.Pair {:a (:u::Term.Var {:n 3}) :d (:u::Term.Nil {})})})]
    (:wat::core::do
      (:wat::kernel::println (:u::len t))
      (:wat::kernel::println (:wat::core::= t t)))))
