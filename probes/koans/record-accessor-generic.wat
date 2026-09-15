;; probes/koans/record-accessor-generic.wat: a defrecord's field accessor, passed as the function
;; argument of a generic function, [T :-> K], together with a Vector of the record for T. The
;; Clojure Koans' group-by (koans/idiom/22-group-by.wat) passes :koan::Person/id so; does T
;; become :probe::Person?

(:wat::core::defrecord :probe::Person [id <- :wat::core::i64])

(:wat::core::defn :probe::keys-of :- [T K] [f <- [T :-> K] xs <- (:wat::core::Vector :- [T])] -> (:wat::core::Vector :- [K])
  (:wat::core::mapv f xs))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:probe::keys-of :probe::Person/id (:wat::core::Vector :- [:probe::Person] (:probe::Person :id 7) (:probe::Person :id 8))))))
