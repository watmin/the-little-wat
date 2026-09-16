;; probes/aoc/persistent-nested-type-alias.wat: the way round the refusal in
;; probes/aoc/persistent-nested-type.wat.
;;
;; The constructor demands that a bracketed type be a type keyword. A typealias IS a type
;; keyword, so naming the inner type first and writing that name in the brackets is accepted,
;; and the map behaves. The refusal is therefore about the spelling, not about what a
;; PersistentMap can hold — which is what makes it a Fix rather than a missing feature.
;;
;; Run from the repository root: wat probes/aoc/persistent-nested-type-alias.wat
;; Expected: exit 0, prints 1 then 7.

(:wat::core::typealias :probe::Cells (:wat::core::PersistentVector :- [:wat::core::i64]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::map::assoc
                        (:wat::core::PersistentMap :- [:wat::core::i64 :probe::Cells])
                        1
                        (:wat::vector::conj (:wat::core::PersistentVector :- [:wat::core::i64]) 7))]
    (:wat::core::do
      (:wat::kernel::println (:wat::map::length m))
      (:wat::core::match (:wat::map::get m 1)
        [:wat::core::Option.Some {:value cells} (:wat::kernel::println (:wat::core::nth cells 0))]
        [:wat::core::Option.None {} (:wat::kernel::println "none")]))))
