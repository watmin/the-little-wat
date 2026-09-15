;; koans/idiom/26-transducers.wat: the transducer koans (koans/literal/26-transducers.tsv), each
;; said the way wat says it, or marked as having no wat route. Keyword spelling throughout, so
;; the checker sees every call (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; There are no transducers. A function from a collection to a lazy Stream plays the part: it
;; composes as functions do, and each sink (into, foldl) takes what it answers. Unlike a
;; transducer, it is tied to its input's type.
;;
;; Run from the repository root: wat koans/idiom/26-transducers.wat

(:wat::core::defn :koan::inc [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :koan::plus [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))
(:wat::core::defn :koan::even? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= 0 (:wat::i64::rem x 2)))

(:wat::core::typealias :koan::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :koan::add-one [xs <- :koan::Ints] -> (:wat::stream::Stream :- [:wat::core::i64])
  (:wat::core::map :koan::inc xs))

(:wat::core::defn :koan::evens-after-inc [xs <- :koan::Ints] -> (:wat::stream::Stream :- [:wat::core::i64])
  (:wat::core::filter :koan::even? (:wat::core::map :koan::inc xs)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:koan::add-one [1 2 3])) [2 3 4]) ; row 1
    (:wat::test::assert-eq (:wat::core::foldl (:wat::core::fn [acc <- :koan::Ints x <- :wat::core::i64] -> :koan::Ints (:wat::core::conj acc x))
                                              (:wat::core::Vector :- [:wat::core::i64]) (:koan::evens-after-inc [1 2 3]))
                           [2 4]) ; row 2
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:koan::evens-after-inc [1 2 3])) [2 4]) ; row 3
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:koan::evens-after-inc [1 2 3])) [2 4]) ; row 4
    (:wat::test::assert-eq (:wat::core::foldl :koan::plus 0 (:koan::evens-after-inc [1 2 3])) 6) ; row 5
    (:wat::kernel::println "koans idiom 26-transducers: ok")))
