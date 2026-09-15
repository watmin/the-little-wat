;; koans/idiom/25-threading-macros.wat: the threading-macro koans that don't port literally
;; (koans/literal/25-threading-macros.tsv), each said the way wat says it, or marked as having
;; no wat route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as
;; in koans/idiom/01-equalities.wat.
;;
;; -> and ->> are wat's own. A map holds one type of value, so the koan's map of a number and a
;; map is a map of maps here, and there is no update-in or get-in (P-017).
;;
;; Run from the repository root: wat koans/idiom/25-threading-macros.wat

(:wat::core::defn :koan::or-else :- [T] [o <- (:wat::core::Option :- [T]) d <- T] -> T
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} d]))

(:wat::core::typealias :koan::KI (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64]))
(:wat::core::typealias :koan::KKI (:wat::core::HashMap :- [:wat::core::keyword :koan::KI]))

(:wat::core::defn :koan::inc [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :koan::plus [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))
(:wat::core::defn :koan::even? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::= 0 (:wat::i64::rem x 2)))

;; update-in and get-in, two levels deep
(:wat::core::defn :koan::update-in2 [m <- :koan::KKI k1 <- :wat::core::keyword k2 <- :wat::core::keyword f <- [:wat::core::i64 :-> :wat::core::i64]] -> :koan::KKI
  (:wat::core::let [inner (:koan::or-else (:wat::hashmap::get m k1) (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64]))]
    (:wat::hashmap::assoc m k1 (:wat::hashmap::assoc inner k2 (f (:koan::or-else (:wat::hashmap::get inner k2) 0))))))

(:wat::core::defn :koan::get-in2 [m <- :koan::KKI k1 <- :wat::core::keyword k2 <- :wat::core::keyword] -> :wat::core::i64
  (:koan::or-else (:wat::hashmap::get (:koan::or-else (:wat::hashmap::get m k1) (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64])) k2) 0))

(:wat::core::defn :koan::n-of-map [m <- :koan::KI a <- :wat::core::String b <- :wat::core::String] -> :wat::core::i64
  (:koan::or-else (:wat::hashmap::get m :n) 0))

(:wat::core::defn :koan::ns-of-coll [a <- :wat::core::String b <- :wat::core::String coll <- (:wat::core::Vector :- [:koan::KI])] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::mapv (:wat::core::fn [m <- :koan::KI] -> :wat::core::i64 (:koan::or-else (:wat::hashmap::get m :n) 0)) coll))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; str takes one argument (F-041); concat threads the same way
    (:wat::test::assert-eq (:wat::core::-> "fig" (:wat::string::concat ", and plum") (:wat::string::concat ", and pear")) "fig, and plum, and pear") ; row 2
    (:wat::test::assert-eq (:wat::core::-> (:wat::core::HashMap :- [:wat::core::keyword :koan::KI])
                                           (:wat::hashmap::assoc :c {:d 4 :e 5})
                                           (:koan::update-in2 :c :e :koan::inc)
                                           (:koan::get-in2 :c :e))
                           6) ; row 4
    (:wat::test::assert-eq (:wat::core::-> (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64]) (:wat::hashmap::assoc :n 1) (:koan::n-of-map "x" "y")) 1) ; row 5
    (:wat::test::assert-eq (:wat::core::->> [1 2 3] (:wat::core::mapv :koan::inc)) [2 3 4]) ; row 6
    (:wat::test::assert-eq (:wat::core::->> [1 2 3 4 5] (:wat::core::mapv :koan::inc) (:wat::core::filterv :koan::even?) (:wat::core::foldl :koan::plus 0)) 12) ; row 7
    (:wat::test::assert-eq (:wat::core::->> [{:n 1} {:n 2} {:n 3}] (:koan::ns-of-coll "x" "y")) [1 2 3]) ; row 8
    (:wat::kernel::println "koans idiom 25-threading-macros: ok")))
