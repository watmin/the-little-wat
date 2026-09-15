;; enum-holding-fn.wat: The Little MLer's chain = Link of int * (int -> chain), a datatype
;; holding a function (an infinite structure unfolded on demand). A Pure enum may not hold a
;; function (the containment rule, R-002), so this is declared Impure.
;; Expected: 1 2 3 (the first three ints of the chain from 1)
(:wat::core::defenum :u::Chain :wat::enum::Impure
  :Link [n <- :wat::core::i64 next <- [:wat::core::i64 :-> :u::Chain]])
(:wat::core::defn :u::ints-from [n <- :wat::core::i64] -> :u::Chain
  (:u::Chain.Link {:n n :next :u::ints-from}))
(:wat::core::defn :u::nth-of [c <- :u::Chain k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match c
    [:u::Chain.Link {:n n :next f}
      (:wat::core::if (:wat::core::= k 0) n (:u::nth-of (f (:wat::core::+ n 1)) (:wat::core::- k 1)))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::nth-of (:u::ints-from 1) 0))
    (:wat::kernel::println (:u::nth-of (:u::ints-from 1) 1))
    (:wat::kernel::println (:u::nth-of (:u::ints-from 1) 2))))
