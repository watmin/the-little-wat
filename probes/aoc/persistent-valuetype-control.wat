;; probes/aoc/persistent-valuetype-control.wat: the POSITIVE CONTROL for
;; probes/aoc/persistent-valuetype.wat.
;;
;; The map is declared to hold i64 values. The value that comes out of it is handed to a
;; function that wants a String. With a real type scheme behind :wat::hashmap::get, V is i64 and
;; the checker must refuse this at startup.
;;
;; Run from the repository root: wat probes/aoc/persistent-valuetype-control.wat
;; Expected: refused at startup, non-zero exit.

(:wat::core::defn :probe::want-string [s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println s))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::hashmap::assoc (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]) 1 1)]
    (:wat::core::match (:wat::hashmap::get m 1)
      [:wat::core::Option.Some {:value v} (:probe::want-string v)]
      [:wat::core::Option.None {} (:wat::kernel::println "none")])))
