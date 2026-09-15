;; probes/koans/record-accessor-generic-map.wat: the shape of the Clojure Koans' group-by
;; (koans/idiom/22-group-by.wat): a generic function over [T :-> K] and a
;; (HashMap :- [K (Vector :- [T])]), given a defrecord's accessor and a map over that record.
;; With a Vector of the record instead, T becomes the record
;; (probes/koans/record-accessor-generic.wat). Here?

(:wat::core::defrecord :probe::Person [id <- :wat::core::i64])

(:wat::core::defn :probe::group-count :- [K T] [f <- [T :-> K] m <- (:wat::core::HashMap :- [K (:wat::core::Vector :- [T])])] -> :wat::core::i64
  (:wat::hashmap::length m))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:probe::group-count :probe::Person/id (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:probe::Person])])))))
