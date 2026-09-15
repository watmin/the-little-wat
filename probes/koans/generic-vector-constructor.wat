;; probes/koans/generic-vector-constructor.wat: a generic function that builds a Vector of its own
;; type variable, (:wat::core::Vector :- [T]). Clojure's iterate, written once for any element
;; type (koans/idiom/11-lazy-sequences.wat). F-009 found a constructor applied to a function's
;; own type variables failing at runtime; is that still so?

(:wat::core::defn :probe::twice :- [T] [x <- T] -> (:wat::core::Vector :- [T])
  (:wat::core::Vector :- [T] x x))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:probe::twice 7))))
