;; generic-recursive-enum.wat: The Little MLer's 'a open_faced_sandwich,
;; Bread of 'a | Slice of 'a open_faced_sandwich, as a generic recursive enum, built at two
;; element types and taken apart by a generic fn. Expected: 3 then 2
(:wat::core::defenum :u::Sandwich :- [A] :wat::enum::Pure
  :Bread [v <- A]
  :Slice [s <- (:u::Sandwich :- [A])])
(:wat::core::defn :u::depth :- [A] [x <- (:u::Sandwich :- [A])] -> :wat::core::i64
  (:wat::core::match x
    [:u::Sandwich.Bread {:v _v} 1]
    [:u::Sandwich.Slice {:s s} (:wat::core::+ 1 (:u::depth s))]))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:u::depth (:u::Sandwich.Slice {:s (:u::Sandwich.Slice {:s (:u::Sandwich.Bread {:v 42})})})))
    (:wat::kernel::println (:u::depth (:u::Sandwich.Slice {:s (:u::Sandwich.Bread {:v "rye"})})))))
