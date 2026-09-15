;; koans/idiom/05-sets.wat: the sets koans that don't port literally
;; (koans/literal/05-sets.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; A set is built by folding a Vector's elements into an empty HashSet. But a HashSet's own
;; elements can't be reached: foldl and into refuse it, and its namespace has only conj,
;; contains?, empty? and length (F-046). So no set operation can be written.
;;
;; Run from the repository root: wat koans/idiom/05-sets.wat

(:wat::core::typealias :koan::Ints (:wat::core::HashSet :- [:wat::core::i64]))

;; set: fold the elements into an empty set
(:wat::core::defn :koan::into-set [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :koan::Ints
  (:wat::core::foldl (:wat::core::fn [s <- :koan::Ints x <- :wat::core::i64] -> :koan::Ints (:wat::hashset::conj s x))
                     (:wat::core::HashSet :- [:wat::core::i64]) xs))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::into-set [7 7 7]) #{7}) ; row 1
    (:wat::test::assert-eq (:koan::into-set [1 2 2 3 3 3]) #{1 2 3}) ; row 3
    ;; row 4 missing: a HashSet's elements can't be enumerated, so no union can be written (F-046)
    ;; row 5 missing: a HashSet's elements can't be enumerated, so no intersection can be written (F-046)
    ;; row 6 missing: a HashSet's elements can't be enumerated, so no difference can be written (F-046)
    (:wat::kernel::println "koans idiom 05-sets: ok")))
