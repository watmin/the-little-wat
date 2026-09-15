;; length-of-string.wat: :wat::core::length on a String, inside a typed keyword-spelled defn.
;; length takes a Vector, HashMap, PersistentMap, PersistentVector, HashSet or List (its own
;; runtime error lists them). Is a String refused at startup, or only at runtime?
;; Expected (if the checker catches it): refused at startup.
(:wat::core::defn :u::len [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::length s))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::len "abc")))
