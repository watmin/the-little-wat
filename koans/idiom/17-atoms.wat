;; koans/idiom/17-atoms.wat: the atoms koans (koans/literal/17-atoms.tsv), each said the way wat
;; says it, or marked as having no wat route. Keyword spelling throughout, so the checker sees
;; every call (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; An atom is state, and state lives on a service (C-014): here the Seasoned Schemer's counter,
;; which holds one i64 and can get, add and reset. Its add is atomic, one message; a swap! of any
;; other function would be a get and a put, which is not. There is no compare-and-set.
;;
;; Run from the repository root: wat koans/idiom/17-atoms.wat

(:wat::load-file! "../../books/seasoned-schemer/lib/counter.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [counter (:ss::new-counter 0)]
    (:wat::core::do
      (:wat::test::assert-eq (:ss::counter-get counter) 0) ; row 1
      (:wat::test::assert-eq (:wat::core::do (:ss::counter-reset! counter 0) (:ss::counter-add! counter 1) (:ss::counter-get counter)) 1) ; row 2
      (:wat::test::assert-eq (:wat::core::do (:ss::counter-reset! counter 5) (:ss::counter-get counter)) 5) ; row 3
      (:wat::test::assert-eq (:wat::core::do (:ss::counter-reset! counter 0) (:ss::counter-add! counter (:wat::core::+ 1 2 3 4 5)) (:ss::counter-get counter)) 15) ; row 4
      ;; row 5 refused: the koan's atom holds a number and then a keyword, and a cell holds one type (and there is no compare-and-set)
      ;; row 6 refused: the koan's atom holds a number and then a keyword, and a cell holds one type (and there is no compare-and-set)
      (:wat::kernel::println "koans idiom 17-atoms: ok"))))
