;; koans/idiom/14-recursion.wat: the recursion koans that don't port literally
;; (koans/literal/14-recursion.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; There is no loop or recur: the loop is a function whose last act is to call itself.
;;
;; Run from the repository root: wat koans/idiom/14-recursion.wat

(:wat::core::defn :koan::even-steps? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::= n 0) true (:wat::core::not (:koan::even-steps? (:wat::core::- n 1)))))

(:wat::core::defn :koan::even-loop? [n <- :wat::core::i64 acc <- :wat::core::bool] -> :wat::core::bool
  (:wat::core::if (:wat::core::= n 0) acc (:koan::even-loop? (:wat::core::- n 1) (:wat::core::not acc))))

(:wat::core::defn :koan::my-reverse [v <- (:wat::core::Vector :- [:wat::core::i64])] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:wat::core::empty? v)
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:koan::my-reverse (:wat::core::rest v)) (:wat::core::Vector :- [:wat::core::i64] (:wat::core::first v)))))

(:wat::core::defn :koan::fact [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 2) 1 (:wat::core::* n (:koan::fact (:wat::core::- n 1)))))

;; the same, over big integers
(:wat::core::defn :koan::fact-big [n <- :wat::core::i64] -> :wat::core::bigint
  (:wat::core::if (:wat::core::< n 2)
    (:wat::i64::to-bigint 1)
    (:wat::bigint::* (:wat::i64::to-bigint n) (:koan::fact-big (:wat::core::- n 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::even-steps? 0) true) ; row 1
    (:wat::test::assert-eq (:koan::even-steps? 1) false) ; row 2
    (:wat::test::assert-eq (:koan::even-loop? 100001 true) false) ; row 3
    (:wat::test::assert-eq (:koan::my-reverse [1]) [1]) ; row 4
    (:wat::test::assert-eq (:koan::my-reverse [6 7 8 9]) [9 8 7 6]) ; row 5
    (:wat::test::assert-eq (:koan::fact 1) 1) ; row 6
    (:wat::test::assert-eq (:koan::fact 3) 6) ; row 7
    (:wat::test::assert-eq (:koan::fact 4) 24) ; row 8
    (:wat::test::assert-eq (:koan::fact 5) 120) ; row 9
    (:wat::test::assert-eq (:koan::fact 20) 2432902008176640000) ; row 10
    ;; a bigint is not orderable (< refuses it, F-047), so the comparison goes through f64
    (:wat::test::assert-eq (:wat::core::< 1000000000000000000000000.0 (:wat::bigint::to-f64 (:koan::fact-big 25))) true) ; row 11
    (:wat::kernel::println "koans idiom 14-recursion: ok")))
