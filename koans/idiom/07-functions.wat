;; koans/idiom/07-functions.wat: the functions koans that don't port literally
;; (koans/literal/07-functions.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; Every function states its parameters' and its result's types; there is no #(...) (F-042);
;; and a builtin like * is not a function value, so it is wrapped in a fn (F-038).
;;
;; Run from the repository root: wat koans/idiom/07-functions.wat

(:wat::core::defn :koan::triple [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 3 n))

(:wat::core::defn :koan::cube [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* n n n))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::cube 3) 27) ; row 1
    (:wat::test::assert-eq (:koan::triple 4) 12) ; row 2
    (:wat::test::assert-eq ((:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 7 n)) 2) 14) ; row 3
    (:wat::test::assert-eq ((:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 10 x)) 3) 30) ; row 4
    (:wat::test::assert-eq ((:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b c)) 3 4 5) 12) ; row 5
    (:wat::test::assert-eq ((:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String (:wat::string::concat "xx" b)) "y" "z") "xxz") ; row 6
    ;; a function that answers a function: its result type is a function type
    (:wat::test::assert-eq
      (((:wat::core::fn [] -> [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]
          (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b))))
       4 5)
      20) ; row 7
    (:wat::test::assert-eq
      ((:wat::core::fn [f <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64 (f 4 5))
       (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b)))
      9) ; row 8
    (:wat::test::assert-eq
      ((:wat::core::fn [f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64 (f 4))
       (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* n n)))
      16) ; row 9
    (:wat::test::assert-eq
      ((:wat::core::fn [f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64 (f 4)) :koan::cube)
      64) ; row 10
    (:wat::kernel::println "koans idiom 07-functions: ok")))
