;; koans/idiom/22-group-by.wat: the group-by koans that don't port literally
;; (koans/literal/22-group-by.tsv), each said the way wat says it, or marked as having no wat
;; route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; There is no group-by (P-017); it is written here, generic over the key and the element. It
;; takes the empty map and the empty group as arguments, because a generic function can't build
;; them from its own type variables (F-009). A map with an :id, a :name and a :last is a record
;; whose absent fields are Options.
;;
;; Run from the repository root: wat koans/idiom/22-group-by.wat

(:wat::core::defn :koan::or-else :- [T] [o <- (:wat::core::Option :- [T]) d <- T] -> T
  (:wat::core::match o
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} d]))

(:wat::core::defn :koan::group-into :- [K T]
  [f <- [T :-> K] m <- (:wat::core::HashMap :- [K (:wat::core::Vector :- [T])]) empty <- (:wat::core::Vector :- [T]) xs <- (:wat::core::Vector :- [T])]
  -> (:wat::core::HashMap :- [K (:wat::core::Vector :- [T])])
  (:wat::core::foldl (:wat::core::fn [acc <- (:wat::core::HashMap :- [K (:wat::core::Vector :- [T])]) x <- T] -> (:wat::core::HashMap :- [K (:wat::core::Vector :- [T])])
                       (:wat::core::let [k (f x)]
                         (:wat::hashmap::assoc acc k (:wat::core::conj (:koan::or-else (:wat::hashmap::get acc k) empty) x))))
                     m xs))

(:wat::core::defn :koan::odd? [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::not (:wat::core::= 0 (:wat::i64::rem x 2))))

(:wat::core::defrecord :koan::Person [id <- :wat::core::i64  name <- (:wat::core::Option :- [:wat::core::String])  last <- (:wat::core::Option :- [:wat::core::String])])

(:wat::core::defn :koan::named [s <- :wat::core::String] -> (:wat::core::Option :- [:wat::core::String]) (:wat::core::Option.Some {:value s}))
(:wat::core::defn :koan::unnamed [] -> (:wat::core::Option :- [:wat::core::String]) (:wat::core::Option.None {}))

(:wat::core::defn :koan::ada [] -> :koan::Person (:koan::Person :id 1 :name (:koan::named "Ada") :last (:koan::unnamed)))
(:wat::core::defn :koan::bob [] -> :koan::Person (:koan::Person :id 2 :name (:koan::named "Bob") :last (:koan::unnamed)))
(:wat::core::defn :koan::byron [] -> :koan::Person (:koan::Person :id 1 :name (:koan::unnamed) :last (:koan::named "Byron")))

(:wat::core::defrecord :koan::Runner [name <- :wat::core::String  late <- :wat::core::bool])

(:wat::core::typealias :koan::People (:wat::core::Vector :- [:koan::Person]))
(:wat::core::typealias :koan::Runners (:wat::core::Vector :- [:koan::Runner]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [people (:wat::core::Vector :- [:koan::Person] (:koan::ada) (:koan::bob) (:koan::byron))
                    nums [1 2 3 4 5]]
    (:wat::core::do
      (:wat::test::assert-eq (:koan::group-into (:wat::core::fn [s <- :wat::core::String] -> :wat::core::i64 (:wat::string::length s)) (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::String])]) (:wat::core::Vector :- [:wat::core::String])
                                                ["hello" "world" "fig" "zap"])
                             {5 ["hello" "world"] 3 ["fig" "zap"]}) ; row 1
      ;; no juxt: the two halves, by group-by and by filterv
      (:wat::test::assert-eq
        (:wat::core::let [g (:koan::group-into :koan::odd? (:wat::core::HashMap :- [:wat::core::bool (:wat::core::Vector :- [:wat::core::i64])]) (:wat::core::Vector :- [:wat::core::i64]) nums)
                          by-group (:wat::core::Tuple (:koan::or-else (:wat::hashmap::get g true) (:wat::core::Vector :- [:wat::core::i64]))
                                                      (:koan::or-else (:wat::hashmap::get g false) (:wat::core::Vector :- [:wat::core::i64])))
                          by-filter (:wat::core::Tuple (:wat::core::filterv :koan::odd? nums)
                                                       (:wat::core::filterv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::not (:koan::odd? x))) nums))]
          (:wat::core::and (:wat::core::= by-group by-filter) (:wat::core::= by-filter (:wat::core::Tuple [1 3 5] [2 4]))))
        true) ; row 2
      (:wat::test::assert-eq (:koan::group-into (:wat::core::fn [p <- :koan::Person] -> :wat::core::i64 (:koan::Person/id p)) (:wat::core::HashMap :- [:wat::core::i64 :koan::People]) (:wat::core::Vector :- [:koan::Person]) people)
                             (:wat::core::HashMap :- [:wat::core::i64 :koan::People]
                               1 (:wat::core::Vector :- [:koan::Person] (:koan::ada) (:koan::byron))
                               2 (:wat::core::Vector :- [:koan::Person] (:koan::bob)))) ; row 3
      ;; a missing key groups under None
      (:wat::test::assert-eq (:koan::group-into (:wat::core::fn [p <- :koan::Person] -> (:wat::core::Option :- [:wat::core::String]) (:koan::Person/name p)) (:wat::core::HashMap :- [(:wat::core::Option :- [:wat::core::String]) :koan::People]) (:wat::core::Vector :- [:koan::Person]) people)
                             (:wat::core::HashMap :- [(:wat::core::Option :- [:wat::core::String]) :koan::People]
                               (:koan::named "Ada") (:wat::core::Vector :- [:koan::Person] (:koan::ada))
                               (:koan::named "Bob") (:wat::core::Vector :- [:koan::Person] (:koan::bob))
                               (:koan::unnamed) (:wat::core::Vector :- [:koan::Person] (:koan::byron)))) ; row 4
      (:wat::test::assert-eq
        (:wat::core::let [cy (:koan::Runner :name "Cy" :late true)
                          ed (:koan::Runner :name "Ed" :late false)
                          di (:koan::Runner :name "Di" :late true)]
          (:wat::core::= (:koan::group-into (:wat::core::fn [r <- :koan::Runner] -> :wat::core::keyword (:wat::core::if (:koan::Runner/late r) :late :early))
                                            (:wat::core::HashMap :- [:wat::core::keyword :koan::Runners]) (:wat::core::Vector :- [:koan::Runner])
                                            (:wat::core::Vector :- [:koan::Runner] cy ed di))
                         (:wat::core::HashMap :- [:wat::core::keyword :koan::Runners]
                           :late (:wat::core::Vector :- [:koan::Runner] cy di)
                           :early (:wat::core::Vector :- [:koan::Runner] ed))))
        true) ; row 5
      (:wat::kernel::println "koans idiom 22-group-by: ok"))))
