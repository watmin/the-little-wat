;; probes/aoc/persistent-nested-type.wat: can a PersistentMap's value type be a parametric type
;; form, the way a HashMap's can?
;;
;; F-057 says the sharing container is the one to accumulate into. Taking that advice in
;; aoc/day05-paths.wat — a map from cost to the squares waiting at that cost — meant writing a
;; PersistentMap whose values are PersistentVectors. The constructor refused it:
;;
;;   malformed :wat::core::PersistentMap form: bracketed type must be a type keyword
;;
;; The HashMap twin of this program (probes/aoc/persistent-nested-type-control.wat) writes the
;; same nesting and passes, so this is not a rule about nested types in general.
;; probes/aoc/persistent-nested-type-alias.wat shows what does work.
;;
;; Run from the repository root: wat probes/aoc/persistent-nested-type.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::map::assoc
                        (:wat::core::PersistentMap :- [:wat::core::i64 (:wat::core::PersistentVector :- [:wat::core::i64])])
                        1
                        (:wat::vector::conj (:wat::core::PersistentVector :- [:wat::core::i64]) 7))]
    (:wat::kernel::println (:wat::map::length m))))
