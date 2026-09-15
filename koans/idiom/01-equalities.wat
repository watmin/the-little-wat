;; koans/idiom/01-equalities.wat: the equalities koans that don't port literally
;; (koans/literal/01-equalities.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014).
;;
;; Markers, one per koan row (tools/koan-tiers.sh reads them):
;;   "; row K" after an assertion: a wat idiom for koan K;
;;   ";; row K missing: ..." no route in wat today (a gap);
;;   ";; row K refused: ..." wat excludes it on purpose (a doctrine).
;;
;; Run from the repository root: wat koans/idiom/01-equalities.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; = takes two arguments, so a chain of them is an and
    (:wat::test::assert-eq (:wat::core::and (:wat::core::= (:wat::core::+ 2 5) 7) (:wat::core::= 7 (:wat::core::+ 3 4))) true) ; row 3
    ;; == across number types: convert, then compare
    (:wat::test::assert-eq (:wat::core::= 3.0 (:wat::i64::to-f64 3)) true) ; row 6
    ;; row 7 refused: an i64 is never nil; a value that may be absent is an Option, and that is its type, not a test
    ;; row 8 refused: a String, a keyword and a symbol are different types, so = between them is refused at check time
    (:wat::test::assert-eq (:wat::keyword::from-string "pear") :pear) ; row 9
    (:wat::test::assert-eq (:wat::core::symbol-node "pear") (:wat::core::quote pear)) ; row 10
    (:wat::kernel::println "koans idiom 01-equalities: ok")))
