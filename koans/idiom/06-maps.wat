;; koans/idiom/06-maps.wat: the maps koans that don't port literally
;; (koans/literal/06-maps.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; A lookup answers an Option, Clojure's nil in the type; or-else and none? read one. wat has
;; no merge or merge-with, so they are written here (P-017).
;;
;; Run from the repository root: wat koans/idiom/06-maps.wat

(:wat::core::defn :koan::or-else :- [T] [o <- (:wat::core::Option :- [T]) d <- T] -> T
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} d]))

(:wat::core::defn :koan::none? :- [T] [o <- (:wat::core::Option :- [T])] -> :wat::core::bool
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} false]
    [:wat::core::Option.None {} true]))

(:wat::core::typealias :koan::KI (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64]))

;; merge: every entry of b, assoc'd onto a
(:wat::core::defn :koan::merge [a <- :koan::KI b <- :koan::KI] -> :koan::KI
  (:wat::core::foldl (:wat::core::fn [m <- :koan::KI k <- :wat::core::keyword] -> :koan::KI
                       (:wat::hashmap::assoc m k (:koan::or-else (:wat::hashmap::get b k) 0)))
                     a (:wat::hashmap::keys b)))

;; merge-with: the same, combining the values of a shared key with f
(:wat::core::defn :koan::merge-with [f <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64] a <- :koan::KI b <- :koan::KI] -> :koan::KI
  (:wat::core::foldl (:wat::core::fn [m <- :koan::KI k <- :wat::core::keyword] -> :koan::KI
                       (:wat::core::let [v (:koan::or-else (:wat::hashmap::get b k) 0)]
                         (:wat::core::match (:wat::hashmap::get m k)
                           [:wat::core::Option.Some {:value old} (:wat::hashmap::assoc m k (f old v))]
                           [:wat::core::Option.None {} (:wat::hashmap::assoc m k v)])))
                     a (:wat::hashmap::keys b)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; no hash-map: the HashMap constructor takes the pairs
    (:wat::test::assert-eq (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64] :x 1 :y 2) {:x 1 :y 2}) ; row 1
    (:wat::test::assert-eq (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64] :x 1) {:x 1}) ; row 2
    ;; get answers an Option
    (:wat::test::assert-eq (:koan::or-else (:wat::core::get {:x 1 :y 2} :y) 0) 2) ; row 4
    ;; a map is not a function of its keys (F-043): get
    (:wat::test::assert-eq (:koan::or-else (:wat::core::get {:x 1 :y 2} :x) 0) 1) ; row 5
    ;; a keyword lookup answers an Option too (F-044)
    (:wat::test::assert-eq (:koan::or-else (:y {:x 1 :y 2}) 0) 2) ; row 6
    (:wat::test::assert-eq (:koan::or-else (:wat::core::get {1998 "Paris" 2007 "Lyon"} 2007) "") "Lyon") ; row 7
    ;; a missing key: None
    (:wat::test::assert-eq (:koan::none? (:wat::core::get {:x 1} :z)) true) ; row 8
    ;; a default: or-else; it must have the values' type, so not the koan's :none
    (:wat::test::assert-eq (:koan::or-else (:wat::core::get {:x 1} :z) 0) 0) ; row 9
    (:wat::test::assert-eq (:koan::merge {:x 1 :y 2} {:z 3}) {:x 1 :y 2 :z 3}) ; row 14
    (:wat::test::assert-eq (:koan::merge-with (:wat::core::fn [p <- :wat::core::i64 q <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ p q)) {:x 1 :y 2} {:y 3 :z 3}) {:x 1 :y 5 :z 3}) ; row 15
    (:wat::test::assert-eq (:wat::core::sort (:wat::hashmap::keys {2007 "Lyon" 1998 "Paris" 2012 "Nice"})) [1998 2007 2012]) ; row 16
    (:wat::test::assert-eq (:wat::core::sort (:wat::hashmap::values {2007 "Lyon" 1998 "Paris" 2012 "Nice"})) ["Lyon" "Nice" "Paris"]) ; row 17
    ;; into {} over the entries: fold over the keys
    (:wat::test::assert-eq
      (:wat::core::let [m {:x 1 :y 2}]
        (:wat::core::foldl (:wat::core::fn [acc <- :koan::KI k <- :wat::core::keyword] -> :koan::KI
                             (:wat::hashmap::assoc acc k (:wat::core::* 10 (:koan::or-else (:wat::hashmap::get m k) 0))))
                           (:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64]) (:wat::hashmap::keys m)))
      {:x 10 :y 20}) ; row 18
    (:wat::kernel::println "koans idiom 06-maps: ok")))
