;; koans/idiom/09-higher-order-functions.wat: the higher-order koans that don't port literally
;; (koans/literal/09-higher-order-functions.tsv), each said the way wat says it, or marked as
;; having no wat route. Keyword spelling throughout, so the checker sees every call (F-014).
;; Markers as in koans/idiom/01-equalities.wat.
;;
;; map and filter are lazy and answer a Stream; mapv and filterv answer a Vector, which is what
;; the koans compare with. reduce is foldl, which always takes its starting value.
;;
;; Run from the repository root: wat koans/idiom/09-higher-order-functions.wat

(:wat::core::defn :koan::none? [o <- (:wat::core::Option :- [:wat::core::keyword])] -> :wat::core::bool
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} false]
    [:wat::core::Option.None {} true]))

;; widened constructors: a bare variant keeps its narrowed type (F-019)
(:wat::core::defn :koan::some-kw [k <- :wat::core::keyword] -> (:wat::core::Option :- [:wat::core::keyword]) (:wat::core::Option.Some {:value k}))
(:wat::core::defn :koan::no-kw [] -> (:wat::core::Option :- [:wat::core::keyword]) (:wat::core::Option.None {}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 3 x)) [1 2 3]) [3 6 9]) ; row 1
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x)) [1 2 3 4]) [1 4 9 16]) ; row 2
    ;; a Vector holds one type, so "a keyword or nil" is an Option of a keyword
    (:wat::test::assert-eq (:wat::core::mapv :koan::none? (:wat::core::Vector :- [(:wat::core::Option :- [:wat::core::keyword])] (:koan::some-kw :a) (:koan::no-kw) (:koan::some-kw :b)))
                           [false true false]) ; row 3
    (:wat::test::assert-eq (:wat::core::filterv (:wat::core::fn [x <- :wat::core::keyword] -> :wat::core::bool false) [:a :b :c]) (:wat::core::Vector :- [:wat::core::keyword])) ; row 4
    (:wat::test::assert-eq (:wat::core::filterv (:wat::core::fn [x <- :wat::core::keyword] -> :wat::core::bool true) [:a :b :c]) [:a :b :c]) ; row 5
    (:wat::test::assert-eq (:wat::core::filterv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::< x 20)) [5 10 15 20 25]) [5 10 15]) ; row 6
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* 10 x))
                                             (:wat::core::filterv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::< x 4)) [1 2 3 4 5]))
                           [10 20 30]) ; row 7
    ;; reduce with no starting value: foldl from the identity
    (:wat::test::assert-eq (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b)) 1 [1 2 3 4 5]) 120) ; row 8
    (:wat::test::assert-eq (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b)) 2 [1 2 3 4 5]) 240) ; row 9
    (:wat::test::assert-eq (:wat::core::foldl (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                                                (:wat::core::if (:wat::core::< (:wat::string::length a) (:wat::string::length b)) b a))
                                              "" ["which" "is" "longest"])
                           "longest") ; row 10
    (:wat::kernel::println "koans idiom 09-higher-order-functions: ok")))
