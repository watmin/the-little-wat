;; koans/idiom/04-vectors.wat: the vectors koans that don't port literally
;; (koans/literal/04-vectors.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; Run from the repository root: wat koans/idiom/04-vectors.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; no vec or vector: the Vector constructor, with its element type
    (:wat::test::assert-eq (:wat::core::Vector :- [:wat::core::i64] 7) [7]) ; row 2
    (:wat::test::assert-eq (:wat::core::Vector :- [:wat::core::nil] nil) [nil]) ; row 3
    (:wat::test::assert-eq (:wat::core::Vector :- [:wat::core::i64] 7 8) [7 8]) ; row 4
    ;; last answers an Option (F-045)
    (:wat::test::assert-eq
      (:wat::core::match (:wat::core::last [:pear :plum :fig :date])
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} :none])
      :date) ; row 7
    ;; no subvec: drop, then take, then back to a Vector
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::keyword]) (:wat::core::take (:wat::core::drop [:pear :plum :fig :date] 1) 2)) [:plum :fig]) ; row 9
    ;; row 10 refused: a quoted list is code (a WatAST) and a Vector is data; = between them is refused at check time
    (:wat::kernel::println "koans idiom 04-vectors: ok")))
