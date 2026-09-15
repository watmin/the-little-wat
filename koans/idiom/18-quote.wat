;; koans/idiom/18-quote.wat: the quote koans that don't port literally
;; (koans/literal/18-quote.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; Quoted forms are code (WatAST). There is no list or cons on them; quasiquote with unquote
;; and splice builds them instead (C-003, P-005).
;;
;; Run from the repository root: wat koans/idiom/18-quote.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; only the quoted list: (list 1 2 3) and (cons 1 [2 3]) have no quoted-list counterpart
    (:wat::test::assert-eq `(1 ~@(:wat::core::quote (2 3))) (:wat::core::quote (1 2 3))) ; row 4
    (:wat::test::assert-eq `(1 ~(:wat::core::quote (+ 2 3))) (:wat::core::quote (1 (+ 2 3)))) ; row 5
    (:wat::test::assert-eq `(1 2 3) (:wat::core::quote (1 2 3))) ; row 6
    (:wat::test::assert-eq `(1 ~(:wat::core::+ 2 3)) (:wat::core::quote (1 5))) ; row 7
    (:wat::kernel::println "koans idiom 18-quote: ok")))
