;; probes/typer/first-of-empty-vector.wat: what does :wat::core::first give for an empty
;; Vector, where the checker lets it be used as the element type itself?
;; (WAT-CHEATSHEET says a Vec accessor returns (Option :- [T]), arc 047.)

(:wat::core::defn :probe::head [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::first xs))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::i64::to-string (:probe::head (:wat::core::Vector :- [:wat::core::i64] 7 8))))
    (:wat::kernel::println "now the empty one")
    (:wat::kernel::println (:wat::i64::to-string (:probe::head (:wat::core::Vector :- [:wat::core::i64]))))
    (:wat::kernel::println "after the empty one")))
