;; arena-cycle.wat: does the Arena model mutable, sharable, even CYCLIC lists? Build
;; (egg egg egg) as three linked nodes, check the links, then point the last node's kdr
;; back at the first and check a bounded walk never reaches ().
;; Expected: 3 / egg / false / true
(:wat::load-file! "../books/seasoned-schemer/lib/arena.wat")
;; walk at most `fuel` links from id; true if () is reached within the fuel
(:wat::core::defn :u::ends-within? [a <- :ss::ArenaRef id <- :wat::core::i64 fuel <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= id -1) true)
    ((:wat::core::= fuel 0) false)
    (:else (:u::ends-within? a (:ss::kdr a id) (:wat::core::- fuel 1)))))
(:wat::core::defn :u::len [a <- :ss::ArenaRef id <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= id -1) 0 (:wat::core::+ 1 (:u::len a (:ss::kdr a id)))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a  (:ss::new-arena)
                    c3 (:ss::kons! a 'egg -1)
                    c2 (:ss::kons! a 'egg c3)
                    c1 (:ss::kons! a 'egg c2)]
    (:wat::core::do
      (:wat::kernel::println (:u::len a c1))
      (:wat::kernel::println (:ss::kar a c2))
      (:ss::set-kdr! a c3 c1)
      (:wat::kernel::println (:u::ends-within? a c1 100))
      (:wat::kernel::println (:wat::core::= (:ss::kdr a c3) c1)))))
