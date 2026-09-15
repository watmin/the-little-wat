;; koans/idiom/03-lists.wat: the lists koans that don't port literally
;; (koans/literal/03-lists.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; A quoted list is code (a WatAST), not data, so the data these koans hold in lists is held
;; here in Vectors.
;;
;; Run from the repository root: wat koans/idiom/03-lists.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; no list: a Vector, built or literal
    (:wat::test::assert-eq (:wat::core::Vector :- [:wat::core::i64] 4 5 6) [4 5 6]) ; row 1
    (:wat::test::assert-eq (:wat::core::first [4 5 6]) 4) ; row 2
    ;; no cons: put an element on the front by concatenation
    (:wat::test::assert-eq (:wat::core::concat [:x] [:y :z]) [:x :y :z]) ; row 7
    ;; conj on a Vector adds at the end; at the front, concatenate
    (:wat::test::assert-eq (:wat::core::concat [:w] [:x :y :z]) [:w :x :y :z]) ; row 8
    ;; a Vector as a stack: first and rest stand in for peek and pop
    (:wat::test::assert-eq (:wat::core::first [:x :y :z]) :x) ; row 9
    (:wat::test::assert-eq (:wat::core::rest [:x :y :z]) [:y :z]) ; row 10
    ;; the rest of an empty Vector dies, and a death comes back as a value through run-thread
    (:wat::test::assert-eq
      (:wat::core::match (:wat::test::run-thread (:wat::core::rest (:wat::core::Vector :- [:wat::core::keyword])))
        [:wat::kernel::RunResult.Passed {} "not empty"]
        [:wat::kernel::RunResult.Failed {:failure f} "empty"])
      "empty") ; row 11
    ;; row 12 missing: the rest of an empty collection dies instead of answering an empty one (F-045)
    (:wat::kernel::println "koans idiom 03-lists: ok")))
