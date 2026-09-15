;; surface.wat: the book's surface (lib-surface.wat) on teacupo, including the order-sensitive
;; case: a relation suspends before it answers, so conde's second line answers first.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "lib-surface.wat")

(:mk2::defrel (:mk2::teacupo t)
  (:mk2::conde ((rs/== t (rs/q 'tea)))
               ((rs/== t (rs/q 'cup)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:mk2::run* q (:mk2::teacupo q)) '(tea cup))
    (:wat::test::assert-eq (:mk2::run* (x y) (:mk2::teacupo x) (:mk2::teacupo y))
                           '((tea tea) (tea cup) (cup tea) (cup cup)))
    (:wat::test::assert-eq (:mk2::run* (x y)
                             (:mk2::conde ((:mk2::teacupo x) (rs/== y (rs/q 'true)))
                                          ((rs/== x (rs/q 'false)) (rs/== y (rs/q 'true)))))
                           '((false true) (tea true) (cup true)))
    (:wat::test::assert-eq (:mk2::run 1 q (:mk2::fresh (a) (rs/== q a))) '(_0))
    (:wat::kernel::println "surface: ok")))
