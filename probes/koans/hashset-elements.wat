;; probes/koans/hashset-elements.wat: can a HashSet's elements be reached? foldl refuses a
;; HashSet ("expects Vector, PersistentVector, List or Stream"), and the hashset namespace has
;; only conj, contains?, empty? and length. Here: into a Vector.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) #{3 4 5}))))
