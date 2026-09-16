;; probes/aoc/persistent-arity.wat: is :wat::map::get, the PersistentMap accessor, checked for
;; arity the way its HashMap twin is?
;;
;; wat-rs's own note of 2026-08-20 (docs/arc/2026/04/109-kill-std/
;; NOTE-the-persistent-family-is-outside-the-type-checker.md) measured thirteen persistent verbs
;; taking seven arguments without complaint, while their std twins raised ArityMismatch. That
;; note describes the retired `PersistentMap/get` spelling; today the verb is an intrinsic named
;; :wat::map::get. Whether the hole was closed with the rename is the question.
;;
;; The same abuse as probes/aoc/persistent-arity-control.wat, on the persistent side.
;;
;; Run from the repository root: wat probes/aoc/persistent-arity.wat

(:wat::core::typealias :probe::Persist (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [m (:wat::map::assoc (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 1 1)
                    r (:wat::map::get m 1 2 3 4 5 6)]
    (:wat::kernel::println "the checker did not object to six extra arguments")))
