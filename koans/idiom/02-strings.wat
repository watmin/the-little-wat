;; koans/idiom/02-strings.wat: the strings koans that don't port literally
;; (koans/literal/02-strings.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; Run from the repository root: wat koans/idiom/02-strings.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; str takes one argument (F-041); concat takes many
    (:wat::test::assert-eq (:wat::string::concat "pear" " and " "plum") "pear and plum") ; row 3
    ;; no character indexing: a one-character substring stands in for the char
    (:wat::test::assert-eq (:wat::string::subs "pear" 1 2) "e") ; row 4
    ;; count doesn't take a String (F-031); the string namespace has its own length
    (:wat::test::assert-eq (:wat::string::length "fig tree!") 9) ; row 5
    ;; row 6 refused: a char and a String are different types, so = between them is refused at check time
    (:wat::test::assert-eq (:wat::string::subs "fig tree" 4 8) "tree") ; row 7
    ;; join always takes its separator
    (:wat::test::assert-eq (:wat::string::join "" [4 5 6]) "456") ; row 8
    (:wat::test::assert-eq (:wat::string::split "a\nb\nc" "\n") ["a" "b" "c"]) ; row 10
    ;; row 11 missing: reverse takes a Vector, PersistentVector or List, not a String, and a String can't be split into characters (split refuses an empty separator)
    ;; row 12 missing: no index-of on strings (contains? answers only whether)
    ;; row 13 missing: no last-index-of on strings
    ;; row 14 missing: no index-of on strings, so no "not found" answer either
    ;; row 16 refused: types are static; a char? predicate has nothing to decide
    ;; row 17 refused: types are static; a char? predicate has nothing to decide
    ;; row 18 refused: types are static; a string? predicate has nothing to decide
    ;; row 19 refused: types are static; a string? predicate has nothing to decide
    ;; no blank?: trim, then ask whether it is empty
    (:wat::test::assert-eq (:wat::string::empty? (:wat::string::trim "")) true) ; row 20
    (:wat::test::assert-eq (:wat::string::empty? (:wat::string::trim "  \t\n ")) true) ; row 21
    (:wat::test::assert-eq (:wat::string::empty? (:wat::string::trim "fig\ntree")) false) ; row 22
    (:wat::kernel::println "koans idiom 02-strings: ok")))
