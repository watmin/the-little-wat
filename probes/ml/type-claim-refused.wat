;; type-claim-refused.wat: The Little MLer ch 1's "no" answers. Is Bread(0) a num
;; open_faced_sandwich? No, its filling is an int. Is One_more_than(Salt) a num? No.
;; Each claim is a keyword-headed body under a declared return type.
;; Expected: refused at startup, with 2 type-check errors.
(:wat::load-file! "../../books/little-mler/lib/ch01-building-blocks.wat")

(:wat::core::defn :mlx::not-a-num-sandwich [] -> (:ml::Sandwich :- [:ml::Num])
  (:ml::Sandwich.Bread {:v 0}))

(:wat::core::defn :mlx::not-a-num [] -> :ml::Num
  (:ml::Num.OneMoreThan {:n (:ml::Seasoning.Salt {})}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println "should not run"))
