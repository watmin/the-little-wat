;; probes/aoc/persistent-valuetype.wat: does a PersistentMap's declared value type constrain
;; anything, or is the annotation inert?
;;
;; This is the question that matters for F-057. probes/aoc/persistent-insert-scaling.wat showed
;; PersistentMap is the container that shares structure — linear where HashMap is quadratic. If
;; its accessors carry no type scheme, then choosing the fast container means giving up the
;; startup checking the slow one gets, and the choice F-057 asks the user to make is a trade,
;; not a free win.
;;
;; The map is declared to hold i64 values; the value that comes out is handed to a function that
;; wants a String. The HashMap twin of this program
;; (probes/aoc/persistent-valuetype-control.wat) says what a checked accessor does with it.
;;
;; Run from the repository root: wat probes/aoc/persistent-valuetype.wat

(:wat::core::defn :probe::want-string [s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println s))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::map::assoc (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 1 1)]
    (:wat::core::match (:wat::map::get m 1)
      [:wat::core::Option.Some {:value v} (:probe::want-string v)]
      [:wat::core::Option.None {} (:wat::kernel::println "none")])))
