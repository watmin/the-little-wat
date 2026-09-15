;; koans/idiom/13-creating-functions.wat: the creating-functions koans that don't port literally
;; (koans/literal/13-creating-functions.tsv), each said the way wat says it, or marked as having
;; no wat route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as
;; in koans/idiom/01-equalities.wat.
;;
;; wat has no partial or comp (P-017); they are written here, generic over their functions'
;; types. A builtin like * is not a function value, so it is wrapped in a fn (F-038).
;;
;; Run from the repository root: wat koans/idiom/13-creating-functions.wat

(:wat::core::defn :koan::square [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))

(:wat::core::defn :koan::partial :- [A B C] [f <- [A B :-> C] a <- A] -> [B :-> C]
  (:wat::core::fn [b <- B] -> C (f a b)))

(:wat::core::defn :koan::comp :- [A B C] [f <- [B :-> C] g <- [A :-> B]] -> [A :-> C]
  (:wat::core::fn [x <- A] -> C (f (g x))))

(:wat::core::defn :koan::inc [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))

(:wat::core::defn :koan::dec [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::- x 1))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; row 1 refused: ["a" :b 'c] mixes a String, a keyword and a symbol, and a Vector holds one type, so keyword? has nothing to decide
    ;; row 2 refused: [nil :x nil "x" 'x] mixes types, and a Vector holds one type
    (:wat::test::assert-eq
      (:wat::core::let [times-7 (:koan::partial (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b)) 7)]
        (times-7 3))
      21) ; row 3
    (:wat::test::assert-eq
      (:wat::core::let [ab (:koan::partial (:wat::core::fn [a <- (:wat::core::Vector :- [:wat::core::keyword]) b <- (:wat::core::Vector :- [:wat::core::keyword])] -> (:wat::core::Vector :- [:wat::core::keyword]) (:wat::core::concat a b))
                                           [:a :b])]
        (ab [:c :d]))
      [:a :b :c :d]) ; row 4
    (:wat::test::assert-eq (:wat::core::let [inc-then-square (:koan::comp :koan::square :koan::inc)] (inc-then-square 3)) 16) ; row 5
    (:wat::test::assert-eq (:wat::core::let [dec-twice (:koan::comp :koan::dec :koan::dec)] (dec-twice 9)) 7) ; row 6
    (:wat::test::assert-eq (:wat::core::let [square-then-dec (:koan::comp :koan::dec :koan::square)] (square-then-dec 10)) 99) ; row 7
    (:wat::kernel::println "koans idiom 13-creating-functions: ok")))
