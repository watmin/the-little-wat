;; probes/aoc/persistent-arity-control.wat: the POSITIVE CONTROL for
;; probes/aoc/persistent-arity.wat.
;;
;; :wat::hashmap::get takes a map and a key. Here it is handed six extra arguments. If the
;; checker is watching this family at all, it must refuse this program at startup. A probe that
;; measures "the checker is silent" is worth nothing unless its control shows the checker can
;; speak, so this file exists to be refused.
;;
;; Run from the repository root: wat probes/aoc/persistent-arity-control.wat
;; Expected: refused at startup, non-zero exit.

(:wat::core::typealias :probe::Hash (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::hashmap::assoc (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]) 1 1)
                    r (:wat::hashmap::get m 1 2 3 4 5 6)]
    (:wat::kernel::println "the checker did not object to six extra arguments")))
