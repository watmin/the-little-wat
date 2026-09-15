;; koans/idiom/12-sequence-comprehensions.wat: the sequence-comprehension koans that don't port
;; literally (koans/literal/12-sequence-comprehensions.tsv), each said the way wat says it, or
;; marked as having no wat route. Keyword spelling throughout, so the checker sees every call
;; (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; There is no for: its body is a mapv, its :when a filterv, and a second binding a fold that
;; concatenates. A pair of a keyword and a number is a Tuple, not a Vector.
;;
;; Run from the repository root: wat koans/idiom/12-sequence-comprehensions.wat

(:wat::core::defn :koan::even? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= 0 (:wat::i64::rem x 2)))

(:wat::core::typealias :koan::Pair (:wat::core::Tuple :- [:wat::core::keyword :wat::core::i64]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::range 0 4)) [0 1 2 3]) ; row 1
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 2 x)) (:wat::core::range 0 4)) [0 2 4 6]) ; row 2
    (:wat::test::assert-eq (:wat::core::filterv :koan::even? (:wat::core::range 0 10)) [0 2 4 6 8]) ; row 3
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))
                                             (:wat::core::filterv :koan::even? (:wat::core::range 0 10)))
                           [0 4 16 36 64]) ; row 4
    (:wat::test::assert-eq
      (:wat::core::foldl (:wat::core::fn [acc <- (:wat::core::Vector :- [:koan::Pair]) l <- :wat::core::keyword] -> (:wat::core::Vector :- [:koan::Pair])
                           (:wat::core::concat acc (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :koan::Pair (:wat::core::Tuple l n)) [1 2])))
                         (:wat::core::Vector :- [:koan::Pair]) [:a :b])
      (:wat::core::Vector :- [:koan::Pair] (:wat::core::Tuple :a 1) (:wat::core::Tuple :a 2) (:wat::core::Tuple :b 1) (:wat::core::Tuple :b 2))) ; row 5
    (:wat::kernel::println "koans idiom 12-sequence-comprehensions: ok")))
