;; koans/idiom/21-partition.wat: the partition koans that don't port literally
;; (koans/literal/21-partition.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; There is no partition. :wat::seq::window gives every contiguous window, and take-nth keeps
;; every step-th of them, which is partition with a step. partition-all is written by hand.
;; take-nth takes its count first, as Clojure's does; take and drop take their collection first.
;;
;; Run from the repository root: wat koans/idiom/21-partition.wat

(:wat::core::typealias :koan::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :koan::Groups (:wat::core::Vector :- [:koan::Ints]))

(:wat::core::defn :koan::partition [n <- :wat::core::i64 step <- :wat::core::i64 xs <- :koan::Ints] -> :koan::Groups
  (:wat::core::into (:wat::core::Vector :- [:koan::Ints]) (:wat::core::take-nth step (:wat::seq::window xs n))))

(:wat::core::defn :koan::partition-all [n <- :wat::core::i64 xs <- :koan::Ints] -> :koan::Groups
  (:wat::core::if (:wat::core::empty? xs)
    (:wat::core::Vector :- [:koan::Ints])
    (:wat::core::concat (:wat::core::Vector :- [:koan::Ints] (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::take xs n)))
                        (:koan::partition-all n (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::drop xs n))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::partition 2 2 [0 1 2 3]) [[0 1] [2 3]]) ; row 1
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [(:wat::core::Vector :- [:wat::core::keyword])])
                                             (:wat::core::take-nth 3 (:wat::seq::window [:a :b :c :d :e] 3)))
                           [[:a :b :c]]) ; row 2
    (:wat::test::assert-eq (:koan::partition-all 3 [0 1 2 3 4]) [[0 1 2] [3 4]]) ; row 3
    (:wat::test::assert-eq (:koan::partition 3 5 [0 1 2 3 4 5 6 7 8 9 10 11 12]) [[0 1 2] [5 6 7] [10 11 12]]) ; row 4
    ;; row 5 refused: numbers padded with a keyword would mix two types in one group, and a Vector holds one
    ;; row 6 refused: numbers padded with keywords and strings would mix types in one group, and a Vector holds one
    (:wat::kernel::println "koans idiom 21-partition: ok")))
