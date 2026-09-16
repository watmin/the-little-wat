;; probes/aoc/persistent-nested-type-control.wat: the POSITIVE CONTROL for
;; probes/aoc/persistent-nested-type.wat.
;;
;; A HashMap whose values are Vectors, built with the nested type form written straight into the
;; constructor. This is the spelling aoc/day05-paths.wat used for its frontier buckets for as
;; long as it existed, so it must pass.
;;
;; Run from the repository root: wat probes/aoc/persistent-nested-type-control.wat
;; Expected: exit 0, prints 1.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::hashmap::assoc
                        (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::i64])])
                        1
                        (:wat::core::Vector :- [:wat::core::i64] 7))]
    (:wat::kernel::println (:wat::hashmap::length m))))
