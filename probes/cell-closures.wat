;; cell-closures.wat: two closures, each owning its own Cell (the book's omnivore and
;; gobbler, each with a private x). Each answers (food previous-food). Can WatAST travel as a
;; service message field, and is each closure's state separate and persistent?
;; Expected: (pizza soup)  (kale bread)  (pasta pizza)
(:wat::load-file! "../books/seasoned-schemer/lib/cell.wat")
(:wat::core::defn :u::make-diner [start <- :wat::WatAST] -> [:wat::WatAST :-> :wat::WatAST]
  (:wat::core::let [x (:ss::new-cell start)]
    (:wat::core::fn [food <- :wat::WatAST] -> :wat::WatAST
      (:wat::core::let [old (:ss::cell-get x)
                        _new (:ss::cell-put! x food)]
        (:wat::core::quasiquote (~food ~old))))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a (:u::make-diner 'soup)
                    b (:u::make-diner 'bread)
                    r1 (a 'pizza)
                    r2 (b 'kale)
                    r3 (a 'pasta)]
    (:wat::core::do
      (:wat::kernel::println r1)
      (:wat::kernel::println r2)
      (:wat::kernel::println r3))))
